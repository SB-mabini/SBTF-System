-- ===========================================================================
-- MTOP System — Push notification dispatch (Android / FCM HTTP v1)
--
-- public.notifications stays the single notification transport: every event
-- (announcement, application decision, appointment, form request, renewal
-- reminder, document release, …) already inserts a row there. This migration
-- layers delivery on top WITHOUT touching any of those business functions:
--
--   insert into notifications  --(trigger)-->  public.push_outbox
--                                                     |
--                       Edge Function `push-dispatch` (polls the outbox)
--                                                     |
--                                     Firebase Cloud Messaging HTTP v1
--
-- Why an outbox instead of calling FCM from the trigger:
--   * a notification is inserted inside a business transaction (approving an
--     application, publishing an announcement); a network call there would
--     block the transaction and could roll it back;
--   * failures can be retried and audited instead of being lost;
--   * one dispatcher covers every current and future notification type.
--
-- Security:
--   * the outbox has RLS enabled and NO policies: only the service role (the
--     Edge Function) can read or write it;
--   * rpc_push_claim_batch() is revoked from anon/authenticated and granted to
--     service_role only;
--   * rpc_register_device_token / rpc_unregister_device_token are SECURITY
--     DEFINER because the device_tokens RLS policies cannot express "reassign
--     this token to me" — they only allow a row whose profile_id already
--     belongs to the caller, which is exactly the wrong way round when the
--     same phone is used by a different driver.
-- ===========================================================================

-- --- outbox -----------------------------------------------------------------
create table if not exists public.push_outbox (
  id              uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique
                    references public.notifications (id) on delete cascade,
  profile_id      uuid not null
                    references public.profiles (id) on delete cascade,
  status          text not null default 'pending'
                    check (status in ('pending', 'sending', 'sent', 'failed', 'skipped')),
  attempts        integer not null default 0 check (attempts >= 0),
  last_error      text,
  -- Earliest moment the dispatcher may pick the row up (retry backoff).
  available_at    timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  sent_at         timestamptz
);

comment on table public.push_outbox is
  'Delivery queue for FCM push notifications. One row per public.notifications insert; written by trigger, drained by the push-dispatch Edge Function. No client role may read or write it.';

create index if not exists push_outbox_due_idx
  on public.push_outbox (available_at)
  where status in ('pending', 'failed', 'sending');

create index if not exists push_outbox_profile_idx
  on public.push_outbox (profile_id);

alter table public.push_outbox enable row level security;

-- RLS without policies already denies every client role; the explicit revoke
-- also removes the table from the PostgREST schema cache surface.
revoke all on public.push_outbox from anon, authenticated;

-- --- enqueue on every notification insert ------------------------------------
create or replace function public.fn_enqueue_push_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.push_outbox (notification_id, profile_id)
  values (new.id, new.user_id)
  on conflict (notification_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_notifications_enqueue_push on public.notifications;
create trigger trg_notifications_enqueue_push
  after insert on public.notifications
  for each row execute function public.fn_enqueue_push_notification();

-- --- device token registration ----------------------------------------------
-- Called by the app on sign-in and whenever FCM rotates the token.
--
-- `on conflict (token) do update` is what makes a shared handset safe: if the
-- token already belonged to the previous driver, it is reassigned to the
-- current one, so the old account stops receiving pushes on this phone.
create or replace function public.rpc_register_device_token(
  p_token    text,
  p_platform text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile_id uuid := public.current_profile_id();
  v_token      text := btrim(coalesce(p_token, ''));
  v_platform   text := lower(btrim(coalesce(p_platform, 'android')));
begin
  if v_profile_id is null then
    raise exception 'Sign in before registering a device token.'
      using errcode = '42501';
  end if;

  -- FCM registration tokens are long opaque strings; anything shorter is a
  -- client bug or an empty value, and storing it would silently break delivery.
  if length(v_token) < 20 then
    raise exception 'Invalid device token.' using errcode = '22023';
  end if;

  if v_platform not in ('android', 'ios') then
    raise exception 'Unsupported platform: %', v_platform using errcode = '22023';
  end if;

  insert into public.device_tokens (profile_id, token, platform, updated_at)
  values (v_profile_id, v_token, v_platform, now())
  on conflict (token) do update
    set profile_id = excluded.profile_id,
        platform   = excluded.platform,
        updated_at = now();
end;
$$;

comment on function public.rpc_register_device_token(text, text) is
  'Upserts the caller''s FCM token, reassigning it from a previous driver when the same handset changes hands.';

-- Called before sign-out, while the session (and therefore auth.uid()) still
-- exists. Only ever deletes a token that belongs to the caller.
create or replace function public.rpc_unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile_id uuid := public.current_profile_id();
  v_token      text := btrim(coalesce(p_token, ''));
begin
  if v_profile_id is null or v_token = '' then
    return;
  end if;

  delete from public.device_tokens
   where token = v_token
     and profile_id = v_profile_id;
end;
$$;

revoke all on function public.rpc_register_device_token(text, text) from public, anon;
revoke all on function public.rpc_unregister_device_token(text) from public, anon;
grant execute on function public.rpc_register_device_token(text, text) to authenticated;
grant execute on function public.rpc_unregister_device_token(text) to authenticated;

-- --- dispatcher claim -------------------------------------------------------
-- Atomically reserves a batch for the Edge Function and returns everything it
-- needs to build the FCM messages, so the function never has to trust client
-- input or issue several round-trips per notification.
--
-- Rows stuck in 'sending' (function crashed mid-batch) are reclaimed after ten
-- minutes; rows that already failed five times are left as 'failed'.
create or replace function public.rpc_push_claim_batch(p_limit integer default 50)
returns table (
  outbox_id        uuid,
  notification_id  uuid,
  profile_id       uuid,
  title            text,
  message          text,
  notification_type text,
  target_type      text,
  target_id        uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return query
  with claimable as (
    select o.id
      from public.push_outbox o
     where (
             (o.status in ('pending', 'failed') and o.available_at <= now())
             or (o.status = 'sending' and o.updated_at < now() - interval '10 minutes')
           )
       and o.attempts < 5
     order by o.available_at, o.created_at
     for update skip locked
     limit greatest(1, least(coalesce(p_limit, 50), 200))
  ),
  claimed as (
    update public.push_outbox o
       set status     = 'sending',
           attempts   = o.attempts + 1,
           updated_at = now()
      from claimable c
     where o.id = c.id
     returning o.*
  )
  select c.id,
         n.id,
         n.user_id,
         n.title,
         n.message,
         n.notification_type::text,
         n.target_type::text,
         n.target_id
    from claimed c
    join public.notifications n on n.id = c.notification_id;
end;
$$;

comment on function public.rpc_push_claim_batch(integer) is
  'Atomically reserves up to p_limit due outbox rows for the push-dispatch Edge Function. Service role only.';

revoke all on function public.rpc_push_claim_batch(integer) from public, anon, authenticated;
grant execute on function public.rpc_push_claim_batch(integer) to service_role;

-- --- housekeeping -----------------------------------------------------------
-- Terminal rows are kept for a month so delivery can be audited, then dropped
-- by the same nightly sweep that already exists for other maintenance work.
create or replace function public.rpc_prune_push_outbox(p_days integer default 30)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_deleted integer;
begin
  delete from public.push_outbox
   where status in ('sent', 'skipped')
     and updated_at < now() - make_interval(days => greatest(coalesce(p_days, 30), 1));

  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.rpc_prune_push_outbox(integer) from public, anon, authenticated;
grant execute on function public.rpc_prune_push_outbox(integer) to service_role;
