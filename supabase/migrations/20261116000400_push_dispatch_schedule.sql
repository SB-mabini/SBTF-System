-- ===========================================================================
-- MTOP System — Push dispatch schedule
--
-- Wires public.push_outbox to the `push-dispatch` Edge Function with pg_cron +
-- pg_net, so delivery needs no manual click in the dashboard.
--
-- The endpoint and the shared secret are NOT in this migration: they live in
-- private.push_dispatch_config, one row per deployed project, written once by
-- an operator (see docs/mobile.md §Push notifications). That keeps the repo
-- free of project-specific URLs and credentials while still making the
-- schedule itself reproducible.
--
-- If either extension or the configuration row is missing, the tick is a
-- no-op: notifications stay queued in push_outbox (status 'pending') and are
-- delivered as soon as the pieces exist. Nothing is lost.
-- ===========================================================================

-- pg_net is what lets the database make the outbound HTTP call. It is
-- available on Supabase; on a local stack that cannot install it the migration
-- still succeeds and the tick simply returns NULL.
do $$
begin
  begin
    create extension if not exists pg_net;
  exception
    when insufficient_privilege then
      raise notice 'pg_net could not be enabled by this role; push dispatch will stay queued until it is enabled from the dashboard.';
    when others then
      raise notice 'pg_net is unavailable (%); push dispatch will stay queued.', sqlerrm;
  end;
end
$$;

-- --- per-project configuration ---------------------------------------------
create schema if not exists private;

create table if not exists private.push_dispatch_config (
  id         boolean primary key default true check (id),
  endpoint   text not null check (endpoint ~ '^https://'),
  secret     text not null check (length(secret) >= 32),
  updated_at timestamptz not null default now()
);

comment on table private.push_dispatch_config is
  'One row: the push-dispatch Edge Function URL and the shared PUSH_CRON_SECRET it expects. Never exposed through PostgREST.';

revoke all on schema private from public, anon, authenticated;
revoke all on private.push_dispatch_config from public, anon, authenticated;

-- --- tick -------------------------------------------------------------------
-- Called once a minute by pg_cron. Returns the pg_net request id, or NULL when
-- there is nothing to call. The function never touches notification content:
-- the Edge Function claims and delivers the rows.
create or replace function public.rpc_push_dispatch_tick()
returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_endpoint   text;
  v_secret     text;
  v_request_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_net') then
    return null;
  end if;

  select endpoint, secret
    into v_endpoint, v_secret
    from private.push_dispatch_config
   where id = true;

  if v_endpoint is null then
    return null;
  end if;

  select net.http_post(
    url     := v_endpoint,
    headers := jsonb_build_object(
                 'content-type', 'application/json',
                 'x-sbtf-cron-secret', v_secret
               ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 15000
  )
  into v_request_id;

  return v_request_id;
end;
$$;

comment on function public.rpc_push_dispatch_tick() is
  'pg_cron entry point: asks the push-dispatch Edge Function to drain push_outbox. No-op until private.push_dispatch_config has a row.';

revoke all on function public.rpc_push_dispatch_tick() from public, anon, authenticated;

-- --- schedules --------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'sbtf-push-dispatch') then
      perform cron.unschedule('sbtf-push-dispatch');
    end if;

    -- Every minute: the shortest interval pg_cron accepts, so a driver hears
    -- about a decision within a minute of it being recorded.
    perform cron.schedule(
      'sbtf-push-dispatch',
      '* * * * *',
      $cron$select public.rpc_push_dispatch_tick()$cron$
    );

    if exists (select 1 from cron.job where jobname = 'sbtf-push-outbox-prune') then
      perform cron.unschedule('sbtf-push-outbox-prune');
    end if;

    -- Daily at 03:45: drop delivered/skipped rows older than 30 days.
    perform cron.schedule(
      'sbtf-push-outbox-prune',
      '45 3 * * *',
      $cron$select public.rpc_prune_push_outbox(30)$cron$
    );

    raise notice 'Scheduled jobs sbtf-push-dispatch (every minute) and sbtf-push-outbox-prune (daily 03:45).';
  else
    raise notice 'Scheduled job skipped: pg_cron is not enabled on this database.';
  end if;
end
$$;
