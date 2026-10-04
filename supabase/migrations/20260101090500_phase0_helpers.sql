-- ===========================================================================
-- SBTF System — Phase 0.6
-- Authorisation helpers, audit logging, notifications and timeline helpers.
--
-- All helpers are SECURITY DEFINER so that Row Level Security policies can
-- call them without triggering recursive policy evaluation on public.profiles.
-- ===========================================================================

-- --- authorisation helpers --------------------------------------------------

-- Returns the profile id of the signed-in user, or NULL when the account is
-- missing or not active. Because every RLS policy is written in terms of this
-- function, deactivating an account immediately removes all data access at the
-- database level — no UI involvement required.
create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id
    from public.profiles p
   where p.auth_user_id = auth.uid()
     and p.account_status = 'active'
   limit 1;
$$;

comment on function public.current_profile_id() is
  'Profile id of the authenticated, active user. NULL for anonymous or deactivated accounts.';

create or replace function public.is_active_account()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles p
     where p.auth_user_id = auth.uid()
       and p.account_status = 'active'
  );
$$;

comment on function public.is_active_account() is
  'True when the signed-in user has a profile whose account_status is active.';

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.role
    from public.profiles p
   where p.auth_user_id = auth.uid()
     and p.account_status = 'active'
   limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles p
     where p.auth_user_id = auth.uid()
       and p.role = 'administrator'
       and p.account_status = 'active'
  );
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles p
     where p.auth_user_id = auth.uid()
       and p.role = 'staff'
       and p.account_status = 'active'
  );
$$;

create or replace function public.is_staff_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles p
     where p.auth_user_id = auth.uid()
       and p.role in ('staff', 'administrator')
       and p.account_status = 'active'
  );
$$;

-- Used by the "my account" screens: unlike current_profile_id() this still
-- returns a value for deactivated accounts, so the app can explain the state.
create or replace function public.current_account_state()
returns table (
  profile_id uuid,
  role public.user_role,
  account_status public.account_status,
  full_name text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.role, p.account_status, p.full_name
    from public.profiles p
   where p.auth_user_id = auth.uid()
   limit 1;
$$;

-- --- audit logging ----------------------------------------------------------
create or replace function public.fn_log_activity(
  p_actor       uuid,
  p_action      public.activity_action,
  p_target_type public.log_target_type default null,
  p_target_id   uuid default null,
  p_metadata    jsonb default '{}'::jsonb,
  p_context     jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
begin
  insert into public.activity_logs (user_id, action, target_type, target_id, metadata, context)
  values (p_actor, p_action, p_target_type, p_target_id, coalesce(p_metadata, '{}'::jsonb), coalesce(p_context, '{}'::jsonb))
  returning id into v_id;

  return v_id;
end;
$$;

comment on function public.fn_log_activity(uuid, public.activity_action, public.log_target_type, uuid, jsonb, jsonb) is
  'Internal append-only audit writer. Not directly callable by clients (see rpc_log_activity for the allow-listed public endpoint).';

-- Client-callable audit endpoint. Only non-privileged, self-scoped events can
-- be written this way, and the actor is always derived from the session.
create or replace function public.rpc_log_activity(
  p_action      public.activity_action,
  p_target_type public.log_target_type default null,
  p_target_id   uuid default null,
  p_metadata    jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_allowed constant public.activity_action[] := array[
    'login', 'logout', 'registration', 'profile_update',
    'notification_preferences_update', 'certificate_generation', 'security_event'
  ]::public.activity_action[];
begin
  if v_actor is null then
    raise exception 'Authentication required to write an activity log entry'
      using errcode = '42501';
  end if;

  if not (p_action = any (v_allowed)) then
    raise exception 'Action % may not be written by a client', p_action
      using errcode = '42501';
  end if;

  -- A client may only ever reference itself or its own records as target.
  if p_target_type = 'profile' and p_target_id is distinct from v_actor then
    raise exception 'Clients may only log activity against their own profile'
      using errcode = '42501';
  end if;

  if p_action = 'login' then
    update public.profiles set last_login_at = now() where id = v_actor;
  end if;

  return public.fn_log_activity(v_actor, p_action, p_target_type, p_target_id, p_metadata);
end;
$$;

-- --- notifications ----------------------------------------------------------
create or replace function public.fn_notify(
  p_user_id       uuid,
  p_title         text,
  p_message       text,
  p_type          public.notification_type,
  p_target_type   public.log_target_type default null,
  p_target_id     uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_prefs record;
begin
  -- Drivers may switch off non-critical notifications; critical status changes
  -- (approval / rejection) and account notices are always delivered.
  if p_type in ('renewal_reminder') then
    select renewal_reminders, email_notifications into v_prefs
      from public.profiles where id = p_user_id;
    if not found or coalesce(v_prefs.renewal_reminders, true) = false then
      return null;
    end if;
  end if;

  insert into public.notifications (user_id, title, message, notification_type, target_type, target_id)
  values (p_user_id, p_title, p_message, p_type, p_target_type, p_target_id)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.fn_notify_staff_and_admin(
  p_title       text,
  p_message     text,
  p_type        public.notification_type,
  p_target_type public.log_target_type default null,
  p_target_id   uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
  v_row record;
begin
  for v_row in
    select p.id from public.profiles p
     where p.role in ('staff', 'administrator')
       and p.account_status = 'active'
  loop
    perform public.fn_notify(v_row.id, p_title, p_message, p_type, p_target_type, p_target_id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- --- application timeline ---------------------------------------------------
create or replace function public.fn_add_application_event(
  p_application_id uuid,
  p_event          public.application_event,
  p_actor          uuid default null,
  p_note           text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
begin
  insert into public.application_status_history (application_id, event, actor_id, note)
  values (p_application_id, p_event, p_actor, p_note)
  returning id into v_id;

  return v_id;
end;
$$;

-- --- numbering helpers ------------------------------------------------------
create or replace function public.fn_next_sequence(p_table text, p_year integer)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_value integer;
begin
  insert into public.franchise_number_sequences (calendar_year, last_value, last_application_value)
  values (p_year, 0, 0)
  on conflict (calendar_year) do nothing;

  if p_table = 'franchise' then
    update public.franchise_number_sequences
       set last_value = last_value + 1, updated_at = now()
     where calendar_year = p_year
    returning last_value into v_value;
  elsif p_table = 'application' then
    update public.franchise_number_sequences
       set last_application_value = last_application_value + 1, updated_at = now()
     where calendar_year = p_year
    returning last_application_value into v_value;
  else
    raise exception 'Unknown sequence %', p_table;
  end if;

  return v_value;
end;
$$;

create or replace function public.fn_generate_verification_code()
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  -- Crockford-inspired alphabet: exactly 32 characters, excluding I, O, 0 and
  -- 1 so that manual entry from a printed certificate stays unambiguous (L is
  -- kept because 1 is not used). 256 is an exact multiple of 32, which makes the
  -- byte-to-character mapping uniform: each character carries exactly 5 bits,
  -- giving 60 bits over 12 characters.
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes    bytea := gen_random_bytes(12);
  v_result   text := '';
  i integer;
begin
  for i in 0..11 loop
    v_result := v_result || substr(v_alphabet, 1 + (get_byte(v_bytes, i) % 32), 1);
  end loop;
  return v_result;
end;
$$;

comment on function public.fn_generate_verification_code() is
  'Opaque 12-character verification identifier embedded in certificate QR codes (60 bits of randomness from a 32-character unambiguous alphabet).';
