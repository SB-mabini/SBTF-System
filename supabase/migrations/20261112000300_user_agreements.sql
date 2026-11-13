-- ===========================================================================
-- User Agreement acceptance audit trail
--
-- Onboarding is completed before sign-in, so the accepted agreement version and
-- timestamp are recorded on the device first. Once the driver has a session,
-- `AgreementService` upserts the same values here, giving the Sangguniang Bayan
-- office a server-side audit record tied to the correct profile.
--
-- One row per profile: a newer acceptance replaces the previous version and
-- timestamp. Language is stored alongside because it is part of the preference
-- the driver chose during onboarding.
--
-- NOTE: this migration must be applied to the hosted Supabase project. Until it
-- is, the mobile sync is a silent no-op and the app continues to work from the
-- local record.
-- ===========================================================================

create table if not exists public.user_agreements (
  profile_id        uuid primary key references public.profiles (id) on delete cascade,
  agreement_version text not null check (length(btrim(agreement_version)) between 1 and 32),
  accepted_at       timestamptz not null default now(),
  language_code     text not null default 'en' check (length(btrim(language_code)) between 2 and 16),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.user_agreements is
  'Latest User Agreement revision accepted by each profile, with timestamp and onboarding language. Written by the mobile app after sign-in.';
comment on column public.user_agreements.accepted_at is
  'When the driver accepted the agreement on the device (UTC).';

create index if not exists user_agreements_accepted_at_idx
  on public.user_agreements (accepted_at);

-- Keep updated_at accurate when an acceptance is replaced.
drop trigger if exists user_agreements_set_updated_at on public.user_agreements;
create trigger user_agreements_set_updated_at
  before update on public.user_agreements
  for each row execute function public.fn_set_updated_at();

-- --- Row Level Security -----------------------------------------------------
alter table public.user_agreements enable row level security;

-- A driver may read only their own acceptance row.
drop policy if exists "user_agreements_select_own" on public.user_agreements;
create policy "user_agreements_select_own"
  on public.user_agreements
  for select
  to authenticated
  using (profile_id = public.current_profile_id());

-- Authorized office personnel may read every acceptance for audit purposes.
drop policy if exists "user_agreements_select_staff" on public.user_agreements;
create policy "user_agreements_select_staff"
  on public.user_agreements
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = public.current_profile_id()
        and p.role in ('admin', 'staff')
    )
  );

-- A driver may insert only their own acceptance.
drop policy if exists "user_agreements_insert_own" on public.user_agreements;
create policy "user_agreements_insert_own"
  on public.user_agreements
  for insert
  to authenticated
  with check (profile_id = public.current_profile_id());

-- A driver may replace only their own acceptance (re-acceptance on a new
-- revision). The check also prevents moving the row to another profile.
drop policy if exists "user_agreements_update_own" on public.user_agreements;
create policy "user_agreements_update_own"
  on public.user_agreements
  for update
  to authenticated
  using (profile_id = public.current_profile_id())
  with check (profile_id = public.current_profile_id());

-- No delete policy: acceptance history is an audit record and is not
-- removable by the driver.

grant select, insert, update on public.user_agreements to authenticated;
