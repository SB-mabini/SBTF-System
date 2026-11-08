-- ===========================================================================
-- SBTF System — Request-form-first workflow (part 2 of 3)
-- Fields, constraints and indexes that let a form request carry the complete
-- vehicle/franchise letter: applicant snapshot, vehicle identity, the combined
-- OR/CR file, the signature, review bookkeeping and the printed marker.
-- ===========================================================================

alter table public.form_requests
  add column if not exists applicant_name        text,
  add column if not exists contact_number        text,
  add column if not exists ctc_number            text,
  add column if not exists vehicle_make          text,
  add column if not exists vehicle_model         text,
  add column if not exists engine_number         text,
  add column if not exists chassis_number        text,
  add column if not exists plate_number          text,
  add column if not exists cr_number             text,
  add column if not exists or_cr_storage_path    text,
  add column if not exists or_cr_file_name       text,
  add column if not exists or_cr_mime_type       text,
  add column if not exists or_cr_file_size_bytes integer,
  add column if not exists signature_storage_path text,
  add column if not exists signature_typed_name  text,
  add column if not exists acknowledged_at       timestamptz,
  add column if not exists reviewed_by           uuid references public.profiles (id) on delete set null,
  add column if not exists reviewed_at           timestamptz,
  add column if not exists rejection_reason      text,
  add column if not exists review_due_at         timestamptz,
  add column if not exists review_reminder_sent_at timestamptz,
  add column if not exists review_overdue_notified_at timestamptz,
  add column if not exists printed_at            timestamptz,
  add column if not exists printed_by            uuid references public.profiles (id) on delete set null;

-- Requests created by the earlier implementation stored the snapshot in
-- `applicant_full_name`; keep them readable under the new column name.
update public.form_requests
   set applicant_name = coalesce(applicant_name, applicant_full_name)
 where applicant_name is null
   and applicant_full_name is not null;

comment on column public.form_requests.ctc_number is
  'Community Tax Certificate (cedula) number printed on the request letter. Required for new requests.';
comment on column public.form_requests.or_cr_storage_path is
  'One combined OR/CR file (front and back in a single PDF or photo) stored in the private franchise-documents bucket.';
comment on column public.form_requests.signature_storage_path is
  'Optional drawn signature PNG stored in the private franchise-documents bucket.';
comment on column public.form_requests.review_due_at is
  'Staff review deadline (SLA). Does not expire an approved request; overdue is only a staff reminder.';

-- Guard rails. Existing/legacy rows are nullable, so each check tolerates null.
-- Backfill the acknowledgement marker for requests issued before this
-- migration, or the issued/rejected consistency check below would fail while
-- validating existing rows.
update public.form_requests
   set acknowledged_at = coalesce(issued_at, requested_at)
 where acknowledged_at is null
   and status in ('issued', 'rejected');

alter table public.form_requests drop constraint if exists form_requests_ctc_length;
alter table public.form_requests add constraint form_requests_ctc_length
  check (ctc_number is null or length(btrim(ctc_number)) between 1 and 40);

alter table public.form_requests drop constraint if exists form_requests_plate_length;
alter table public.form_requests add constraint form_requests_plate_length
  check (plate_number is null or length(btrim(plate_number)) between 3 and 20);

alter table public.form_requests drop constraint if exists form_requests_engine_length;
alter table public.form_requests add constraint form_requests_engine_length
  check (engine_number is null or length(btrim(engine_number)) between 3 and 40);

alter table public.form_requests drop constraint if exists form_requests_chassis_length;
alter table public.form_requests add constraint form_requests_chassis_length
  check (chassis_number is null or length(btrim(chassis_number)) between 3 and 40);

alter table public.form_requests drop constraint if exists form_requests_rejection_reason_required;
alter table public.form_requests add constraint form_requests_rejection_reason_required
  check (status <> 'rejected'
         or (rejection_reason is not null
             and length(btrim(rejection_reason)) between 10 and 1000
             and reviewed_by is not null
             and reviewed_at is not null));

alter table public.form_requests drop constraint if exists form_requests_acknowledged_consistency;
alter table public.form_requests add constraint form_requests_acknowledged_consistency
  check (status not in ('issued', 'rejected') or acknowledged_at is not null);

-- Fast lookup of the approved request that unlocks an application.
create index if not exists form_requests_issued_lookup_idx
  on public.form_requests (requested_by, application_type)
  where status = 'issued';

-- Staff console: pending review ordered by deadline.
create index if not exists form_requests_review_due_idx
  on public.form_requests (review_due_at)
  where status = 'requested';

-- Duplicate-vehicle detection.
create index if not exists form_requests_vehicle_idx
  on public.form_requests (upper(plate_number), upper(engine_number), upper(chassis_number));
