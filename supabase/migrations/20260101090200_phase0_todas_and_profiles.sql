-- ===========================================================================
-- SBTF System — Phase 0.3
-- TODAs, TODA membership masterlist, and application user profiles.
--
-- Authentication itself is delegated entirely to Supabase Auth (auth.users).
-- public.profiles only stores the application-level profile, and is linked to
-- Supabase Auth through auth_user_id. No password material is ever stored here.
-- ===========================================================================

-- --- todas ------------------------------------------------------------------
create table if not exists public.todas (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  name         text not null unique,
  barangay_code text references public.barangays (code) on delete set null,
  zone         text,
  -- Maintained automatically from public.toda_members by trigger
  -- (fn_toda_sync_members_count) so the counter can never drift from the roster.
  members_count integer not null default 0 check (members_count >= 0),
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.todas is 'Tricycle Operators and Drivers Associations (TODA) accredited in the Municipality of Mabini.';
comment on column public.todas.members_count is 'Derived from public.toda_members; kept in sync by trigger.';

-- --- toda_members -----------------------------------------------------------
-- Anonymised membership masterlist. These rows intentionally carry no personal
-- data: they exist so that TODA membership statistics (members vs. franchise
-- coverage) can be analysed without processing personal information.
-- A roster entry may optionally be claimed by / linked to a real profile once
-- the operator completes registration.
create table if not exists public.toda_members (
  id           uuid primary key default gen_random_uuid(),
  toda_id      uuid not null references public.todas (id) on delete cascade,
  member_ref   text not null unique,
  display_name text not null,
  profile_id   uuid,
  year_joined  smallint check (year_joined between 1990 and 2100),
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.toda_members is
  'Anonymised TODA membership masterlist (no personal data). Supports membership vs. franchise-coverage analytics.';

create index if not exists toda_members_toda_id_idx on public.toda_members (toda_id);
create index if not exists toda_members_profile_id_idx on public.toda_members (profile_id);

-- --- profiles ---------------------------------------------------------------
create table if not exists public.profiles (
  id                 uuid primary key default gen_random_uuid(),
  auth_user_id       uuid unique references auth.users (id) on delete set null,
  role               public.user_role not null default 'driver'
                     references public.roles (code) on update cascade,
  first_name         text not null check (length(btrim(first_name)) between 1 and 80),
  middle_name        text check (middle_name is null or length(btrim(middle_name)) between 1 and 80),
  last_name          text not null check (length(btrim(last_name)) between 1 and 80),
  email              text not null,
  contact_number     text check (contact_number is null or contact_number ~ '^[0-9+()\- ]{7,20}$'),
  address_line       text check (address_line is null or length(address_line) <= 200),
  barangay_code      text references public.barangays (code) on delete set null,
  toda_id            uuid references public.todas (id) on delete set null,
  account_status     public.account_status not null default 'active',
  status_reason      text,
  email_notifications boolean not null default true,
  renewal_reminders   boolean not null default true,
  last_login_at      timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  full_name          text generated always as (
                       btrim(first_name || ' ' || coalesce(middle_name || ' ', '') || last_name)
                     ) stored
);

comment on table public.profiles is
  'Application profile for every user. Password material is never stored: authentication is fully delegated to Supabase Auth (auth.users).';
comment on column public.profiles.auth_user_id is
  'Reference to auth.users.id. NULL only for anonymised masterlist entries that have not registered yet.';

-- Case-insensitive uniqueness for e-mail.
create unique index if not exists profiles_email_lower_key on public.profiles (lower(email));
create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists profiles_toda_id_idx on public.profiles (toda_id);
create index if not exists profiles_account_status_idx on public.profiles (account_status);

-- --- updated_at maintenance -------------------------------------------------
create or replace function public.fn_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.fn_set_updated_at() is 'Generic BEFORE UPDATE trigger that stamps updated_at.';

drop trigger if exists trg_todas_updated_at on public.todas;
create trigger trg_todas_updated_at before update on public.todas
  for each row execute function public.fn_set_updated_at();

drop trigger if exists trg_toda_members_updated_at on public.toda_members;
create trigger trg_toda_members_updated_at before update on public.toda_members
  for each row execute function public.fn_set_updated_at();

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.fn_set_updated_at();

-- --- members_count synchronisation -----------------------------------------
create or replace function public.fn_toda_sync_members_count()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_toda_id uuid;
begin
  v_toda_id := coalesce(new.toda_id, old.toda_id);

  update public.todas t
     set members_count = (
           select count(*) from public.toda_members m
            where m.toda_id = v_toda_id and m.is_active
         ),
         updated_at = now()
   where t.id = v_toda_id;

  return coalesce(new, old);
end;
$$;

comment on function public.fn_toda_sync_members_count() is
  'Keeps todas.members_count consistent with the anonymised roster in toda_members.';

drop trigger if exists trg_toda_members_count on public.toda_members;
create trigger trg_toda_members_count
  after insert or update of is_active, toda_id or delete on public.toda_members
  for each row execute function public.fn_toda_sync_members_count();

-- --- profile provisioning on Supabase Auth sign-up --------------------------
-- Roles are read from raw_app_meta_data, which the Supabase Auth API does NOT
-- accept from client SDKs (only the service role can write it). This makes
-- self-registration incapable of requesting an elevated role: user-supplied
-- raw_user_meta_data is ignored for authorisation purposes.
create or replace function public.fn_handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.user_role := 'driver';
  v_barangay text;
begin
  begin
    if new.raw_app_meta_data ? 'role' then
      v_role := (new.raw_app_meta_data ->> 'role')::public.user_role;
    end if;
  exception when others then
    v_role := 'driver';
  end;

  v_barangay := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'barangay_code', '')), '');
  if v_barangay is not null and not exists (select 1 from public.barangays b where b.code = v_barangay) then
    v_barangay := null;
  end if;

  insert into public.profiles (
    auth_user_id, role, first_name, middle_name, last_name, email,
    contact_number, address_line, barangay_code
  )
  values (
    new.id,
    v_role,
    coalesce(nullif(btrim(coalesce(new.raw_user_meta_data ->> 'first_name', '')), ''), 'Unnamed'),
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'middle_name', '')), ''),
    coalesce(nullif(btrim(coalesce(new.raw_user_meta_data ->> 'last_name', '')), ''), 'User'),
    new.email,
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'contact_number', '')), ''),
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'address_line', '')), ''),
    v_barangay
  )
  on conflict (auth_user_id) do nothing;

  return new;
end;
$$;

comment on function public.fn_handle_new_auth_user() is
  'Creates the application profile when a Supabase Auth account is created. Role is taken from raw_app_meta_data (service-role only) and defaults to driver.';

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.fn_handle_new_auth_user();
