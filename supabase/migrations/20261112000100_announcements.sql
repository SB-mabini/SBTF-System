-- ===========================================================================
-- SBTF System — Announcements and broadcasting
--
-- Announcements are content records with an audience. Publishing fans the
-- content out into the EXISTING public.notifications table (via fn_notify),
-- so there is a single notification transport for the whole system. Drivers
-- read announcements directly through RLS, and their notification deep-links
-- back to the announcement row.
-- ===========================================================================

-- --- enum values ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_enum e
      join pg_type t on t.oid = e.enumtypid
     where t.typname = 'notification_type' and e.enumlabel = 'announcement'
  ) then
    alter type public.notification_type add value 'announcement';
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_enum e
      join pg_type t on t.oid = e.enumtypid
     where t.typname = 'log_target_type' and e.enumlabel = 'announcement'
  ) then
    alter type public.log_target_type add value 'announcement';
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'announcement_status') then
    create type public.announcement_status as enum ('draft', 'published', 'archived');
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'announcement_audience') then
    create type public.announcement_audience as enum (
      'all_drivers',
      'all_members',
      'toda',
      'drivers'
    );
  end if;
end
$$;

-- --- activity actions -------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_enum e
      join pg_type t on t.oid = e.enumtypid
     where t.typname = 'activity_action' and e.enumlabel = 'announcement_created'
  ) then
    alter type public.activity_action add value 'announcement_created';
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_enum e
      join pg_type t on t.oid = e.enumtypid
     where t.typname = 'activity_action' and e.enumlabel = 'announcement_published'
  ) then
    alter type public.activity_action add value 'announcement_published';
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_enum e
      join pg_type t on t.oid = e.enumtypid
     where t.typname = 'activity_action' and e.enumlabel = 'announcement_archived'
  ) then
    alter type public.activity_action add value 'announcement_archived';
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_enum e
      join pg_type t on t.oid = e.enumtypid
     where t.typname = 'activity_action' and e.enumlabel = 'announcement_deleted'
  ) then
    alter type public.activity_action add value 'announcement_deleted';
  end if;
end
$$;

-- --- tables -----------------------------------------------------------------
create table if not exists public.announcements (
  id              uuid primary key default gen_random_uuid(),
  title           text not null check (length(btrim(title)) between 1 and 120),
  body            text not null check (length(btrim(body)) between 1 and 4000),
  status          public.announcement_status not null default 'draft',
  audience        public.announcement_audience not null default 'all_drivers',
  published_at    timestamptz,
  archived_at     timestamptz,
  recipient_count integer not null default 0 check (recipient_count >= 0),
  created_by      uuid references public.profiles (id) on delete set null,
  updated_by      uuid references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.announcements is
  'System-wide announcements and broadcasts. Staff and administrators manage them; drivers read those addressed to them. Publishing fans out into public.notifications.';

create index if not exists announcements_status_published_idx
  on public.announcements (status, published_at desc);

create table if not exists public.announcement_targets (
  id              uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  toda_id         uuid references public.todas (id) on delete cascade,
  profile_id      uuid references public.profiles (id) on delete cascade,
  created_at      timestamptz not null default now(),
  constraint announcement_targets_one_target check (num_nonnulls(toda_id, profile_id) = 1)
);

create unique index if not exists announcement_targets_toda_uniq
  on public.announcement_targets (announcement_id, toda_id)
  where toda_id is not null;

create unique index if not exists announcement_targets_profile_uniq
  on public.announcement_targets (announcement_id, profile_id)
  where profile_id is not null;

create index if not exists announcement_targets_announcement_idx
  on public.announcement_targets (announcement_id);

comment on table public.announcement_targets is
  'The TODAs or individual drivers an announcement is addressed to. Used only when audience is toda or drivers.';

-- --- recipient resolution ---------------------------------------------------
create or replace function public.fn_announcement_recipients(p_announcement_id uuid)
returns table (profile_id uuid)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select distinct p.id
    from public.announcements a
    join public.profiles p
      on p.role = 'driver'
     and p.account_status = 'active'
   where a.id = p_announcement_id
     and a.status = 'published'
     and (
       a.audience = 'all_drivers'
       or (a.audience = 'all_members' and p.toda_id is not null)
       or (
         a.audience = 'toda'
         and exists (
           select 1 from public.announcement_targets t
            where t.announcement_id = a.id and t.toda_id = p.toda_id
         )
       )
       or (
         a.audience = 'drivers'
         and exists (
           select 1 from public.announcement_targets t
            where t.announcement_id = a.id and t.profile_id = p.id
         )
       )
     );
$$;

comment on function public.fn_announcement_recipients(uuid) is
  'Resolves the active driver accounts an announcement is addressed to.';

-- --- save / publish / archive / delete --------------------------------------
create or replace function public.fn_sync_announcement_notifications(p_announcement_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_announcement public.announcements%rowtype;
  v_count integer := 0;
  v_row record;
begin
  select * into v_announcement from public.announcements where id = p_announcement_id;
  if not found then
    return 0;
  end if;

  -- Remove deliveries for recipients who are no longer addressed by an
  -- archived announcement (published rows only keep their audience).
  if v_announcement.status <> 'published' then
    delete from public.notifications
     where notification_type = 'announcement'
       and target_type = 'announcement'
       and target_id = p_announcement_id;
    return 0;
  end if;

  -- Drop deliveries for drivers who are no longer in the resolved audience.
  delete from public.notifications n
   where n.notification_type = 'announcement'
     and n.target_type = 'announcement'
     and n.target_id = p_announcement_id
     and not exists (
       select 1 from public.fn_announcement_recipients(p_announcement_id) r
        where r.profile_id = n.user_id
     );

  for v_row in select * from public.fn_announcement_recipients(p_announcement_id) loop
    insert into public.notifications (user_id, title, message, notification_type, target_type, target_id)
    select v_row.profile_id, v_announcement.title, left(v_announcement.body, 1000), 'announcement', 'announcement', p_announcement_id
     where not exists (
       select 1 from public.notifications n
        where n.notification_type = 'announcement'
          and n.target_type = 'announcement'
          and n.target_id = p_announcement_id
          and n.user_id = v_row.profile_id
     );

    -- Keep content in step when a published announcement is edited.
    update public.notifications
       set title = v_announcement.title,
           message = left(v_announcement.body, 1000)
     where notification_type = 'announcement'
       and target_type = 'announcement'
       and target_id = p_announcement_id
       and user_id = v_row.profile_id;

    v_count := v_count + 1;
  end loop;

  update public.announcements
     set recipient_count = v_count,
         updated_at = now()
   where id = p_announcement_id;

  return v_count;
end;
$$;

create or replace function public.rpc_save_announcement(
  p_id           uuid,
  p_title        text,
  p_body         text,
  p_audience     public.announcement_audience,
  p_toda_ids     uuid[] default '{}',
  p_profile_ids  uuid[] default '{}',
  p_status       public.announcement_status default 'draft',
  p_published_at timestamptz default null
)
returns public.announcements
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_row public.announcements%rowtype;
  v_title text := btrim(coalesce(p_title, ''));
  v_body text := btrim(coalesce(p_body, ''));
  v_toda uuid;
  v_profile uuid;
begin
  if not public.is_staff_or_admin() or v_actor is null then
    raise exception 'Only staff and administrators may manage announcements'
      using errcode = '42501';
  end if;

  if length(v_title) = 0 then
    raise exception 'An announcement needs a title' using errcode = '22023';
  end if;
  if length(v_body) = 0 then
    raise exception 'An announcement needs a message' using errcode = '22023';
  end if;

  if p_audience = 'toda' and coalesce(array_length(p_toda_ids, 1), 0) = 0 then
    raise exception 'Select at least one TODA for this audience' using errcode = '22023';
  end if;
  if p_audience = 'drivers' and coalesce(array_length(p_profile_ids, 1), 0) = 0 then
    raise exception 'Select at least one driver for this audience' using errcode = '22023';
  end if;

  if p_id is null then
    insert into public.announcements (title, body, status, audience, published_at, created_by, updated_by)
    values (
      v_title,
      v_body,
      p_status,
      p_audience,
      case when p_status = 'published' then coalesce(p_published_at, now()) else null end,
      v_actor,
      v_actor
    )
    returning * into v_row;
  else
    update public.announcements
       set title = v_title,
           body = v_body,
           status = p_status,
           audience = p_audience,
           published_at = case
             when p_status = 'published' then coalesce(published_at, p_published_at, now())
             else published_at
           end,
           archived_at = case when p_status = 'archived' then coalesce(archived_at, now()) else null end,
           updated_by = v_actor,
           updated_at = now()
     where id = p_id
     returning * into v_row;

    if not found then
      raise exception 'That announcement no longer exists' using errcode = 'P0002';
    end if;

    delete from public.announcement_targets where announcement_id = p_id;
  end if;

  if p_audience = 'toda' then
    foreach v_toda in array p_toda_ids loop
      insert into public.announcement_targets (announcement_id, toda_id)
      values (v_row.id, v_toda)
      on conflict do nothing;
    end loop;
  elsif p_audience = 'drivers' then
    foreach v_profile in array p_profile_ids loop
      insert into public.announcement_targets (announcement_id, profile_id)
      values (v_row.id, v_profile)
      on conflict do nothing;
    end loop;
  end if;

  perform public.fn_sync_announcement_notifications(v_row.id);

  perform public.fn_log_activity(
    v_actor,
    case
      when p_status = 'published' then 'announcement_published'::public.activity_action
      else 'announcement_created'::public.activity_action
    end,
    'announcement',
    v_row.id,
    jsonb_build_object('title', v_row.title, 'audience', v_row.audience, 'status', v_row.status)
  );

  select * into v_row from public.announcements where id = v_row.id;
  return v_row;
end;
$$;

create or replace function public.rpc_delete_announcement(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
begin
  if not public.is_staff_or_admin() or v_actor is null then
    raise exception 'Only staff and administrators may delete announcements'
      using errcode = '42501';
  end if;

  delete from public.notifications
   where notification_type = 'announcement'
     and target_type = 'announcement'
     and target_id = p_id;

  delete from public.announcements where id = p_id;

  perform public.fn_log_activity(
    v_actor, 'announcement_deleted', 'announcement', p_id,
    jsonb_build_object('deleted', true)
  );
end;
$$;

-- --- RLS --------------------------------------------------------------------
alter table public.announcements enable row level security;
alter table public.announcement_targets enable row level security;

drop policy if exists "announcements: staff manage all" on public.announcements;
create policy "announcements: staff manage all"
  on public.announcements for select to authenticated
  using (public.is_staff_or_admin());

drop policy if exists "announcements: drivers read addressed published rows" on public.announcements;
create policy "announcements: drivers read addressed published rows"
  on public.announcements for select to authenticated
  using (
    status = 'published'
    and exists (
      select 1 from public.fn_announcement_recipients(id) r
       where r.profile_id = public.current_profile_id()
    )
  );

drop policy if exists "announcement_targets: staff manage all" on public.announcement_targets;
create policy "announcement_targets: staff manage all"
  on public.announcement_targets for select to authenticated
  using (public.is_staff_or_admin());

-- --- grants -----------------------------------------------------------------
revoke all on table public.announcements, public.announcement_targets from anon, authenticated;
grant select on table public.announcements, public.announcement_targets to authenticated;

revoke all on function public.fn_announcement_recipients(uuid) from public, anon, authenticated;
revoke all on function public.fn_sync_announcement_notifications(uuid) from public, anon, authenticated;
grant execute on function public.rpc_save_announcement(uuid, text, text, public.announcement_audience, uuid[], uuid[], public.announcement_status, timestamptz) to authenticated;
grant execute on function public.rpc_delete_announcement(uuid) to authenticated;

-- --- document template settings --------------------------------------------
-- Franchise Editor settings live with the existing 'certificate' category so
-- no category constraint change is required. They are additive and keep the
-- current keys working as defaults.
insert into public.system_settings (key, value, data_type, category, label, description, is_public) values
  ('document_logo_enabled', 'true'::jsonb, 'boolean', 'certificate',
   'Show logo on documents', 'Prints the official Mabini logo in the document letterhead.', true),
  ('document_logo_position', '"left"'::jsonb, 'string', 'certificate',
   'Logo position', 'Where the official logo is printed: left, center or right.', true),
  ('document_logo_width', '22'::jsonb, 'number', 'certificate',
   'Logo width (mm)', 'Width of the printed logo in millimetres (16–40).', true),
  ('document_header_align', '"center"'::jsonb, 'string', 'certificate',
   'Letterhead alignment', 'Alignment of the letterhead text: left, center or right.', true),
  ('document_board_name', '"SANGGUNIANG BAYAN NG MABINI"'::jsonb, 'string', 'certificate',
   'Board / office heading', 'Bold heading printed under the municipality name.', true),
  ('document_section_order', '["particulars","conditions","order","signatures","payment","footer"]'::jsonb, 'json', 'certificate',
   'Optional block order', 'Order of the configurable document blocks.', true)
on conflict (key) do nothing;
