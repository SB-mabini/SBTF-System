-- ===========================================================================
-- SBTF System — Phase 1.2
-- Workflow tables for the staff-driven franchising process: form requests,
-- scheduled appointments/hearings, document release, plus the processing
-- pipeline columns on franchise_applications.
--
-- `status` remains the decision outcome (pending/approved/rejected); the new
-- `stage` column carries the docs/process.md pipeline.
-- ===========================================================================

-- --- franchise_applications: pipeline and decision bookkeeping ---------------
alter table public.franchise_applications
  add column if not exists stage public.application_stage not null default 'submitted',
  add column if not exists assigned_staff_id uuid references public.profiles (id) on delete set null,
  add column if not exists for_compliance_reason text,
  add column if not exists endorsed_to text,
  add column if not exists endorsement_reference text,
  add column if not exists endorsed_at timestamptz,
  add column if not exists endorsed_by uuid references public.profiles (id) on delete set null,
  add column if not exists approving_authority text,
  add column if not exists decision_reference text,
  add column if not exists decision_recorded_at timestamptz;

comment on column public.franchise_applications.stage is
  'Processing pipeline shown to staff (docs/process.md). The decision outcome remains application_status.';
comment on column public.franchise_applications.assigned_staff_id is
  'Staff member currently handling this application (optional).';
comment on column public.franchise_applications.for_compliance_reason is
  'Reason the application was moved to For Compliance.';
comment on column public.franchise_applications.endorsed_to is
  'Body/office the application was endorsed/transmitted to.';
comment on column public.franchise_applications.approving_authority is
  'External authority (official, committee or resolution) whose decision was recorded.';
comment on column public.franchise_applications.decision_reference is
  'Official reference of the recorded decision (resolution/order number).';

create index if not exists franchise_applications_stage_idx on public.franchise_applications (stage);
create index if not exists franchise_applications_assigned_idx on public.franchise_applications (assigned_staff_id);

-- Backfill the pipeline for rows that predate the stage column.
update public.franchise_applications
   set stage = case
                 when status = 'approved' then 'completed'::public.application_stage
                 when status = 'rejected' then 'rejected'::public.application_stage
                 when review_started_at is not null then 'under_verification'::public.application_stage
                 else 'submitted'::public.application_stage
               end
 where stage = 'submitted';

-- --- form requests ----------------------------------------------------------
create table if not exists public.form_requests (
  id              uuid primary key default gen_random_uuid(),
  form_number     text not null unique,
  requested_by    uuid not null references public.profiles (id) on delete restrict,
  toda_id         uuid references public.todas (id) on delete set null,
  application_type public.application_type not null,
  status          public.form_request_status not null default 'requested',
  purpose         text check (purpose is null or length(btrim(purpose)) between 1 and 500),
  requested_at    timestamptz not null default now(),
  issued_at       timestamptz,
  issued_by       uuid references public.profiles (id) on delete set null,
  converted_application_id uuid unique references public.franchise_applications (id) on delete set null,
  cancelled_at    timestamptz,
  cancel_reason   text check (cancel_reason is null or length(cancel_reason) <= 500),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint form_requests_issued_consistency
    check (status <> 'issued' or (issued_at is not null and issued_by is not null)),
  constraint form_requests_converted_consistency
    check (status <> 'converted' or converted_application_id is not null),
  constraint form_requests_cancelled_consistency
    check (status <> 'cancelled' or cancelled_at is not null)
);

comment on table public.form_requests is
  'Pre-application form requests filed by drivers/operators in the mobile app; staff issue and later convert them into an application.';

create index if not exists form_requests_requested_by_idx on public.form_requests (requested_by);
create index if not exists form_requests_status_idx on public.form_requests (status);

drop trigger if exists trg_form_requests_updated_at on public.form_requests;
create trigger trg_form_requests_updated_at before update on public.form_requests
  for each row execute function public.fn_set_updated_at();

-- --- appointments / hearings ------------------------------------------------
create table if not exists public.application_appointments (
  id             uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.franchise_applications (id) on delete cascade,
  kind           public.appointment_kind not null,
  status         public.appointment_status not null default 'scheduled',
  scheduled_at   timestamptz not null,
  venue          text not null check (length(btrim(venue)) between 1 and 200),
  outcome        text check (outcome is null or length(outcome) <= 1000),
  notes          text check (notes is null or length(notes) <= 1000),
  scheduled_by   uuid references public.profiles (id) on delete set null,
  completed_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint application_appointments_outcome_consistency
    check (status not in ('completed', 'no_show') or completed_at is not null)
);

comment on table public.application_appointments is
  'In-person appointments (evaluation, physical-document submission, hearings, release). Read-only to clients; written only through staff RPCs.';

create index if not exists application_appointments_application_idx
  on public.application_appointments (application_id, scheduled_at);
create index if not exists application_appointments_scheduled_idx
  on public.application_appointments (scheduled_at);

drop trigger if exists trg_application_appointments_updated_at on public.application_appointments;
create trigger trg_application_appointments_updated_at before update on public.application_appointments
  for each row execute function public.fn_set_updated_at();

-- --- document releases ------------------------------------------------------
create table if not exists public.document_releases (
  id                    uuid primary key default gen_random_uuid(),
  application_id        uuid not null references public.franchise_applications (id) on delete cascade,
  record_id             uuid not null unique references public.franchise_records (id) on delete cascade,
  released_at           timestamptz not null default now(),
  received_by_name      text not null check (length(btrim(received_by_name)) between 1 and 120),
  received_by_id_number text check (received_by_id_number is null or length(btrim(received_by_id_number)) between 1 and 60),
  relationship          text check (relationship is null or length(btrim(relationship)) between 1 and 60),
  released_by           uuid references public.profiles (id) on delete set null,
  acknowledged          boolean not null default true,
  notes                 text check (notes is null or length(notes) <= 500),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

comment on table public.document_releases is
  'Record that a certificate/document was physically released to and acknowledged by the operator or their representative.';

create index if not exists document_releases_application_idx on public.document_releases (application_id);

drop trigger if exists trg_document_releases_updated_at on public.document_releases;
create trigger trg_document_releases_updated_at before update on public.document_releases
  for each row execute function public.fn_set_updated_at();

-- --- extend the numbering helper with a form-request sequence ---------------
alter table public.franchise_number_sequences
  add column if not exists last_form_request_value integer not null default 0 check (last_form_request_value >= 0);

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
  elsif p_table = 'form_request' then
    update public.franchise_number_sequences
       set last_form_request_value = last_form_request_value + 1, updated_at = now()
     where calendar_year = p_year
    returning last_form_request_value into v_value;
  else
    raise exception 'Unknown sequence %', p_table;
  end if;

  return v_value;
end;
$$;
