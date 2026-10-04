-- ===========================================================================
-- SBTF System — Phase 0.4
-- Franchise domain: applications, documents, records, numbering and timeline.
-- ===========================================================================

-- --- franchise_number_sequences --------------------------------------------
create table if not exists public.franchise_number_sequences (
  calendar_year integer primary key check (calendar_year between 2000 and 2200),
  -- Franchise numbers (MAB-TR-YYYY-NNNNNN)
  last_value    integer not null default 0 check (last_value >= 0),
  -- Application numbers (APP-YYYY-NNNNNN); added in the workflow migration.
  last_application_value integer not null default 0 check (last_application_value >= 0),
  updated_at    timestamptz not null default now()
);

comment on table public.franchise_number_sequences is
  'Per-year counter used to generate franchise numbers. Not accessible to clients.';

-- --- franchise_applications -------------------------------------------------
create table if not exists public.franchise_applications (
  id                     uuid primary key default gen_random_uuid(),
  application_number     text not null unique,
  applicant_id           uuid not null references public.profiles (id) on delete restrict,
  application_type       public.application_type not null,
  status                 public.application_status not null default 'pending',
  toda_id                uuid not null references public.todas (id) on delete restrict,

  -- Operator information as declared on the application
  operator_first_name    text not null check (length(btrim(operator_first_name)) between 1 and 80),
  operator_middle_name   text check (operator_middle_name is null or length(btrim(operator_middle_name)) between 1 and 80),
  operator_last_name     text not null check (length(btrim(operator_last_name)) between 1 and 80),
  operator_contact_number text not null check (operator_contact_number ~ '^[0-9+()\- ]{7,20}$'),
  operator_address_line  text not null check (length(btrim(operator_address_line)) between 5 and 200),
  operator_barangay_code text references public.barangays (code) on delete set null,
  operator_email         text,

  -- Vehicle information
  vehicle_make           text not null check (length(btrim(vehicle_make)) between 1 and 60),
  vehicle_model          text not null check (length(btrim(vehicle_model)) between 1 and 60),
  vehicle_year           smallint not null check (vehicle_year between 1950 and 2100),
  vehicle_color          text not null check (length(btrim(vehicle_color)) between 2 and 40),
  plate_number           text not null check (length(btrim(plate_number)) between 3 and 20),
  engine_number          text not null check (length(btrim(engine_number)) between 3 and 40),
  chassis_number         text not null check (length(btrim(chassis_number)) between 3 and 40),
  seating_capacity       smallint not null default 5 check (seating_capacity between 1 and 12),
  mtop_number            text,
  body_number            text,

  -- Renewal linkage: which franchise record is being renewed
  renewal_of_record_id   uuid,
  remarks                text check (remarks is null or length(remarks) <= 1000),

  -- Workflow bookkeeping
  submitted_at           timestamptz not null default now(),
  review_started_at      timestamptz,
  review_started_by      uuid references public.profiles (id) on delete set null,
  reviewed_by            uuid references public.profiles (id) on delete set null,
  reviewed_at            timestamptz,
  rejection_reason       text check (rejection_reason is null or length(btrim(rejection_reason)) between 10 and 1000),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint franchise_applications_rejection_reason_required
    check (status <> 'rejected' or rejection_reason is not null),
  constraint franchise_applications_reviewed_consistency
    check (status = 'pending' or (reviewed_by is not null and reviewed_at is not null)),
  constraint franchise_applications_plate_not_blank check (length(btrim(plate_number)) > 0)
);

comment on table public.franchise_applications is
  'Franchise applications (new and renewal). Status is fixed to pending/approved/rejected; the document-verification and review stages are captured by application_status_history plus the review_* columns.';

create index if not exists franchise_applications_applicant_idx on public.franchise_applications (applicant_id);
create index if not exists franchise_applications_status_idx on public.franchise_applications (status);
create index if not exists franchise_applications_type_idx on public.franchise_applications (application_type);
create index if not exists franchise_applications_toda_idx on public.franchise_applications (toda_id);
create index if not exists franchise_applications_submitted_idx on public.franchise_applications (submitted_at desc);
create index if not exists franchise_applications_reviewed_idx on public.franchise_applications (reviewed_at desc);

drop trigger if exists trg_franchise_applications_updated_at on public.franchise_applications;
create trigger trg_franchise_applications_updated_at before update on public.franchise_applications
  for each row execute function public.fn_set_updated_at();

-- --- franchise_documents ----------------------------------------------------
create table if not exists public.franchise_documents (
  id                  uuid primary key default gen_random_uuid(),
  application_id      uuid not null references public.franchise_applications (id) on delete cascade,
  document_type       public.document_type not null,
  storage_path        text not null check (length(btrim(storage_path)) between 3 and 400),
  file_name           text not null,
  file_size_bytes     integer check (file_size_bytes is null or file_size_bytes between 1 and 10485760),
  mime_type           text check (mime_type is null or mime_type in ('application/pdf', 'image/jpeg', 'image/png')),
  verification_status public.document_verification_status not null default 'pending',
  verified_by         uuid references public.profiles (id) on delete set null,
  verified_at         timestamptz,
  remarks             text check (remarks is null or length(remarks) <= 500),
  uploaded_at         timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint franchise_documents_one_per_type unique (application_id, document_type),
  constraint franchise_documents_verification_consistency
    check (verification_status = 'pending' or (verified_by is not null and verified_at is not null)),
  constraint franchise_documents_rejected_requires_remarks
    check (verification_status <> 'rejected' or (remarks is not null and length(btrim(remarks)) >= 5))
);

comment on table public.franchise_documents is
  'Submitted documentary requirements. Files live in the private storage bucket "franchise-documents" and are only reachable through RLS-checked signed URLs.';

create index if not exists franchise_documents_application_idx on public.franchise_documents (application_id);
create index if not exists franchise_documents_status_idx on public.franchise_documents (verification_status);

drop trigger if exists trg_franchise_documents_updated_at on public.franchise_documents;
create trigger trg_franchise_documents_updated_at before update on public.franchise_documents
  for each row execute function public.fn_set_updated_at();

-- --- franchise_records ------------------------------------------------------
create table if not exists public.franchise_records (
  id                       uuid primary key default gen_random_uuid(),
  application_id           uuid not null unique references public.franchise_applications (id) on delete restrict,
  operator_id              uuid not null references public.profiles (id) on delete restrict,
  toda_id                  uuid not null references public.todas (id) on delete restrict,
  franchise_number         text not null unique,
  -- Secure verification identifier: the only value embedded in the QR code.
  verification_code        text not null unique,
  issued_at                timestamptz not null,
  expires_at               timestamptz not null,
  certificate_storage_path text,
  certificate_generated_at timestamptz,
  renewed_by_record_id     uuid references public.franchise_records (id) on delete set null,
  archived                 boolean not null default false,
  archived_at              timestamptz,
  archived_by              uuid references public.profiles (id) on delete set null,
  archive_reason           text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),

  constraint franchise_records_period_valid check (expires_at > issued_at),
  constraint franchise_records_archive_consistency
    check ((archived = false and archived_at is null) or (archived = true and archived_at is not null and archive_reason is not null))
);

comment on table public.franchise_records is
  'Issued franchise records. Created only through rpc_staff_approve_application(); clients never write to this table directly.';
comment on column public.franchise_records.verification_code is
  'Opaque identifier embedded in the certificate QR code. Resolved through rpc_verify_certificate().';

create index if not exists franchise_records_operator_idx on public.franchise_records (operator_id);
create index if not exists franchise_records_expires_idx on public.franchise_records (expires_at);
create index if not exists franchise_records_toda_idx on public.franchise_records (toda_id);
create index if not exists franchise_records_archived_idx on public.franchise_records (archived);

drop trigger if exists trg_franchise_records_updated_at on public.franchise_records;
create trigger trg_franchise_records_updated_at before update on public.franchise_records
  for each row execute function public.fn_set_updated_at();

-- --- application_status_history --------------------------------------------
-- Powers the driver-facing status timeline (specification §3.8) without
-- introducing a fourth application status.
create table if not exists public.application_status_history (
  id             uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.franchise_applications (id) on delete cascade,
  event          public.application_event not null,
  actor_id       uuid references public.profiles (id) on delete set null,
  note           text check (note is null or length(note) <= 500),
  created_at     timestamptz not null default now()
);

comment on table public.application_status_history is
  'Immutable event timeline for each application. Written by SECURITY DEFINER functions only.';

create index if not exists application_status_history_application_idx
  on public.application_status_history (application_id, created_at);

-- --- renewal reminder de-duplication ---------------------------------------
create table if not exists public.renewal_reminders_sent (
  record_id   uuid not null references public.franchise_records (id) on delete cascade,
  window_days integer not null check (window_days between 1 and 365),
  sent_at     timestamptz not null default now(),
  primary key (record_id, window_days)
);

comment on table public.renewal_reminders_sent is
  'Guarantees each renewal reminder window (90/60/30 days) is sent at most once per franchise record.';
