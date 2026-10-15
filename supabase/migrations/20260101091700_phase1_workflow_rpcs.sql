-- ===========================================================================
-- SBTF System — Phase 1.3
-- Staff-driven workflow RPCs (docs/process.md).
--
-- Authority rule for Phase 1: all application and record handling is performed
-- by STAFF only. Administrators keep read-only visibility (their SELECT
-- policies are unchanged in the RLS migration); they can no longer review,
-- verify, decide, issue certificates or archive records.
--
-- Timeline, audit and notification rows for table mutations are written by the
-- triggers in Phase 1.4, exactly as in Phase 0 — these functions only validate
-- business rules and move columns.
-- ===========================================================================

-- ===========================================================================
-- Internal: issue (or return) the franchise record for an application
-- ===========================================================================
create or replace function public.fn_staff_issue_franchise_record(p_application_id uuid)
returns public.franchise_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_app      public.franchise_applications;
  v_record   public.franchise_records;
  v_validity integer;
  v_prefix   text;
  v_year     integer := extract(year from now())::int;
  v_seq      integer;
  v_number   text;
  v_code     text;
begin
  select * into v_record
    from public.franchise_records
   where application_id = p_application_id;

  if v_record.id is not null then
    return v_record;
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  select coalesce((value #>> '{}')::integer, 12) into v_validity
    from public.system_settings where key = 'franchise_validity_months';
  v_validity := coalesce(v_validity, 12);

  select coalesce(value #>> '{}', 'MAB-TR') into v_prefix
    from public.system_settings where key = 'franchise_number_prefix';
  v_prefix := coalesce(nullif(btrim(v_prefix), ''), 'MAB-TR');

  v_seq := public.fn_next_sequence('franchise', v_year);
  v_number := v_prefix || '-' || v_year || '-' || lpad(v_seq::text, 6, '0');
  v_code := public.fn_generate_verification_code();

  insert into public.franchise_records (
    application_id, operator_id, toda_id, franchise_number, verification_code, issued_at, expires_at
  )
  values (
    v_app.id, v_app.applicant_id, v_app.toda_id, v_number, v_code,
    now(), now() + make_interval(months => v_validity)
  )
  returning * into v_record;

  if v_app.renewal_of_record_id is not null then
    update public.franchise_records
       set renewed_by_record_id = v_record.id
     where id = v_app.renewal_of_record_id
       and renewed_by_record_id is null;
  end if;

  return v_record;
end;
$$;

comment on function public.fn_staff_issue_franchise_record(uuid) is
  'Creates the franchise record for an application, or returns the existing one. Internal: called by staff RPCs, never by clients.';

-- ===========================================================================
-- STAFF: start review → pipeline stage "under_verification"
-- ===========================================================================
create or replace function public.rpc_staff_start_review(p_application_id uuid)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_app   public.franchise_applications;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set review_started_at = coalesce(review_started_at, now()),
         review_started_by = coalesce(review_started_by, v_actor),
         assigned_staff_id  = coalesce(assigned_staff_id, v_actor),
         stage              = 'under_verification'
   where id = v_app.id
  returning * into v_app;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: assign (or clear) the handling staff member
-- ===========================================================================
create or replace function public.rpc_staff_assign_application(
  p_application_id uuid,
  p_staff_id       uuid
)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_app public.franchise_applications;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if p_staff_id is not null
     and not exists (
       select 1 from public.profiles p
        where p.id = p_staff_id
          and p.role in ('staff', 'administrator')
     ) then
    raise exception 'Applications may only be assigned to a staff member' using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set assigned_staff_id = p_staff_id
   where id = p_application_id
  returning * into v_app;

  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: verify or reject a submitted document
-- ===========================================================================
create or replace function public.rpc_staff_verify_document(
  p_document_id uuid,
  p_status      public.document_verification_status,
  p_remarks     text default null
)
returns public.franchise_documents
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_doc   public.franchise_documents;
  v_app   public.franchise_applications;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if p_status = 'rejected' and length(btrim(coalesce(p_remarks, ''))) < 5 then
    raise exception 'A remark of at least 5 characters is required when rejecting a document'
      using errcode = 'P0001';
  end if;

  select * into v_doc from public.franchise_documents where id = p_document_id for update;
  if not found then
    raise exception 'Document not found' using errcode = 'P0002';
  end if;

  select * into v_app from public.franchise_applications where id = v_doc.application_id;
  if v_app.status <> 'pending' then
    raise exception 'Documents of a % application can no longer be verified', v_app.status
      using errcode = 'P0001';
  end if;

  update public.franchise_documents
     set verification_status = p_status,
         verified_by = case when p_status = 'pending' then null else v_actor end,
         verified_at = case when p_status = 'pending' then null else now() end,
         remarks = case
                     when p_status = 'pending' then null
                     when p_status = 'verified' then null
                     else btrim(p_remarks)
                   end
   where id = p_document_id
  returning * into v_doc;

  return v_doc;
end;
$$;

-- ===========================================================================
-- STAFF: send an application to "For Compliance" (deficiency loop)
-- ===========================================================================
create or replace function public.rpc_staff_request_compliance(
  p_application_id uuid,
  p_reason         text
)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_app    public.franchise_applications;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if length(v_reason) < 10 then
    raise exception 'A compliance note of at least 10 characters is required' using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set stage = 'for_compliance',
         for_compliance_reason = v_reason
   where id = p_application_id
     and status = 'pending'
  returning * into v_app;

  if not found then
    raise exception 'Only a pending application can be sent for compliance' using errcode = 'P0001';
  end if;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: mark all documents verified → stage "verified"
-- ===========================================================================
create or replace function public.rpc_staff_mark_verified(p_application_id uuid)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_app         public.franchise_applications;
  v_outstanding integer;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  select count(*) into v_outstanding
    from unnest(enum_range(null::public.document_type)) as dt
   where not exists (
           select 1 from public.franchise_documents d
            where d.application_id = v_app.id
              and d.document_type = dt
              and d.verification_status = 'verified'
         );

  if v_outstanding > 0 then
    raise exception 'Cannot mark verified: % documentary requirement(s) are still unverified',
      v_outstanding using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set stage = 'verified'
   where id = v_app.id
  returning * into v_app;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: record the application in the franchise register → stage "recorded"
-- ===========================================================================
create or replace function public.rpc_staff_record_application(p_application_id uuid)
returns public.franchise_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_app         public.franchise_applications;
  v_record      public.franchise_records;
  v_outstanding integer;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  select count(*) into v_outstanding
    from unnest(enum_range(null::public.document_type)) as dt
   where not exists (
           select 1 from public.franchise_documents d
            where d.application_id = v_app.id
              and d.document_type = dt
              and d.verification_status = 'verified'
         );

  if v_outstanding > 0 then
    raise exception 'Cannot record yet: % documentary requirement(s) are still unverified',
      v_outstanding using errcode = 'P0001';
  end if;

  v_record := public.fn_staff_issue_franchise_record(v_app.id);

  update public.franchise_applications
     set stage = 'recorded'
   where id = v_app.id;

  return v_record;
end;
$$;

-- ===========================================================================
-- STAFF: record an endorsement/transmittal → stage "for_approval"
-- ===========================================================================
create or replace function public.rpc_staff_record_endorsement(
  p_application_id uuid,
  p_endorsed_to    text,
  p_reference      text default null,
  p_note           text default null
)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor      uuid := public.current_profile_id();
  v_app        public.franchise_applications;
  v_endorsed   text := btrim(coalesce(p_endorsed_to, ''));
  v_reference  text := nullif(btrim(coalesce(p_reference, '')), '');
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if length(v_endorsed) < 2 then
    raise exception 'The endorsing body/office is required' using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set stage = 'for_approval',
         endorsed_to = v_endorsed,
         endorsement_reference = v_reference,
         endorsed_at = now(),
         endorsed_by = v_actor
   where id = p_application_id
     and status = 'pending'
  returning * into v_app;

  if not found then
    raise exception 'Only a pending application can be endorsed' using errcode = 'P0001';
  end if;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: record the externally-made decision
--   approved → status approved, stage ready_for_release (issues the record)
--   rejected → status rejected, stage rejected (reason mandatory)
-- ===========================================================================
create or replace function public.rpc_staff_record_decision(
  p_application_id      uuid,
  p_decision            text,
  p_approving_authority text default null,
  p_reference           text default null,
  p_reason              text default null
)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor     uuid := public.current_profile_id();
  v_app       public.franchise_applications;
  v_decision  text := lower(btrim(coalesce(p_decision, '')));
  v_authority text := nullif(btrim(coalesce(p_approving_authority, '')), '');
  v_reference text := nullif(btrim(coalesce(p_reference, '')), '');
  v_reason    text := btrim(coalesce(p_reason, ''));
  v_outstanding integer;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if v_decision not in ('approved', 'rejected') then
    raise exception 'decision must be either "approved" or "rejected"' using errcode = 'P0001';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  if v_decision = 'approved' then
    if v_authority is null then
      raise exception 'The approving authority must be recorded when approving' using errcode = 'P0001';
    end if;

    if v_reference is null then
      raise exception 'The decision reference (resolution/order) is required when approving'
        using errcode = 'P0001';
    end if;

    select count(*) into v_outstanding
      from unnest(enum_range(null::public.document_type)) as dt
     where not exists (
             select 1 from public.franchise_documents d
              where d.application_id = v_app.id
                and d.document_type = dt
                and d.verification_status = 'verified'
           );

    if v_outstanding > 0 then
      raise exception 'Cannot approve yet: % documentary requirement(s) are still unverified',
        v_outstanding using errcode = 'P0001';
    end if;

    perform public.fn_staff_issue_franchise_record(v_app.id);

    update public.franchise_applications
       set status = 'approved',
           stage = 'ready_for_release',
           reviewed_by = v_actor,
           reviewed_at = now(),
           rejection_reason = null,
           approving_authority = v_authority,
           decision_reference = v_reference,
           decision_recorded_at = now()
     where id = v_app.id
    returning * into v_app;

  else
    if length(v_reason) < 10 then
      raise exception 'A rejection reason of at least 10 characters is required' using errcode = 'P0001';
    end if;

    if length(v_reason) > 1000 then
      raise exception 'The rejection reason must not exceed 1000 characters' using errcode = 'P0001';
    end if;

    update public.franchise_applications
       set status = 'rejected',
           stage = 'rejected',
           rejection_reason = v_reason,
           reviewed_by = v_actor,
           reviewed_at = now(),
           approving_authority = v_authority,
           decision_reference = v_reference,
           decision_recorded_at = now()
     where id = v_app.id
    returning * into v_app;
  end if;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: approve an application → issue the franchise record
--
-- Retained for compatibility with the existing console and tests. New screens
-- use rpc_staff_record_decision(), which also captures the approving authority.
-- ===========================================================================
create or replace function public.rpc_staff_approve_application(p_application_id uuid)
returns public.franchise_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor       uuid := public.current_profile_id();
  v_app         public.franchise_applications;
  v_record      public.franchise_records;
  v_outstanding integer;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  select count(*) into v_outstanding
    from unnest(enum_range(null::public.document_type)) as dt
   where not exists (
           select 1 from public.franchise_documents d
            where d.application_id = v_app.id
              and d.document_type = dt
              and d.verification_status = 'verified'
         );

  if v_outstanding > 0 then
    raise exception 'Cannot approve yet: % documentary requirement(s) are still unverified',
      v_outstanding using errcode = 'P0001';
  end if;

  v_record := public.fn_staff_issue_franchise_record(v_app.id);

  update public.franchise_applications
     set status = 'approved',
         stage = 'ready_for_release',
         reviewed_by = v_actor,
         reviewed_at = now(),
         rejection_reason = null,
         decision_recorded_at = coalesce(decision_recorded_at, now())
   where id = v_app.id;

  return v_record;
end;
$$;

comment on function public.rpc_staff_approve_application(uuid) is
  'Approves a fully verified application and issues a franchise record (staff only). Prefer rpc_staff_record_decision() to also capture the approving authority.';

-- ===========================================================================
-- STAFF: reject an application (reason mandatory)
-- ===========================================================================
create or replace function public.rpc_staff_reject_application(
  p_application_id uuid,
  p_reason         text
)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_app   public.franchise_applications;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if length(v_reason) < 10 then
    raise exception 'A rejection reason of at least 10 characters is required' using errcode = 'P0001';
  end if;

  if length(v_reason) > 1000 then
    raise exception 'The rejection reason must not exceed 1000 characters' using errcode = 'P0001';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set status = 'rejected',
         stage = 'rejected',
         rejection_reason = v_reason,
         reviewed_by = v_actor,
         reviewed_at = now()
   where id = v_app.id
  returning * into v_app;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: release the certificate/document → stage "released"
-- ===========================================================================
create or replace function public.rpc_staff_release_document(
  p_application_id      uuid,
  p_received_by_name    text,
  p_received_by_id      text default null,
  p_relationship        text default null,
  p_notes               text default null
)
returns public.document_releases
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor    uuid := public.current_profile_id();
  v_app      public.franchise_applications;
  v_record   public.franchise_records;
  v_release  public.document_releases;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'approved' then
    raise exception 'Only an approved application can be released' using errcode = 'P0001';
  end if;

  if v_app.stage = 'released' or v_app.stage = 'completed' then
    raise exception 'This application has already been released' using errcode = 'P0001';
  end if;

  select * into v_record from public.franchise_records where application_id = v_app.id;
  if not found then
    raise exception 'Franchise record not found' using errcode = 'P0002';
  end if;

  insert into public.document_releases (
    application_id, record_id, released_at, received_by_name,
    received_by_id_number, relationship, released_by, acknowledged, notes
  )
  values (
    v_app.id, v_record.id, now(), btrim(p_received_by_name),
    nullif(btrim(coalesce(p_received_by_id, '')), ''),
    nullif(btrim(coalesce(p_relationship, '')), ''),
    v_actor, true, nullif(btrim(coalesce(p_notes, '')), '')
  )
  returning * into v_release;

  update public.franchise_applications
     set stage = 'released'
   where id = v_app.id;

  return v_release;
end;
$$;

-- ===========================================================================
-- STAFF: complete the application → stage "completed"
-- ===========================================================================
create or replace function public.rpc_staff_complete_application(p_application_id uuid)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_app public.franchise_applications;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  update public.franchise_applications
     set stage = 'completed'
   where id = p_application_id
     and stage = 'released'
  returning * into v_app;

  if not found then
    raise exception 'Only a released application can be completed' using errcode = 'P0001';
  end if;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: schedule an appointment / hearing
-- ===========================================================================
create or replace function public.rpc_staff_schedule_appointment(
  p_application_id uuid,
  p_kind           public.appointment_kind,
  p_scheduled_at   timestamptz,
  p_venue          text,
  p_notes          text default null
)
returns public.application_appointments
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_app   public.application_appointments;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if p_scheduled_at is null then
    raise exception 'An appointment date and time is required' using errcode = 'P0001';
  end if;

  if length(btrim(coalesce(p_venue, ''))) < 1 then
    raise exception 'An appointment venue is required' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.franchise_applications a where a.id = p_application_id) then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  insert into public.application_appointments (
    application_id, kind, status, scheduled_at, venue, notes, scheduled_by
  )
  values (
    p_application_id, p_kind, 'scheduled', p_scheduled_at, btrim(p_venue),
    nullif(btrim(coalesce(p_notes, '')), ''), v_actor
  )
  returning * into v_app;

  return v_app;
end;
$$;

create or replace function public.rpc_staff_update_appointment(
  p_appointment_id uuid,
  p_status         public.appointment_status,
  p_outcome        text default null,
  p_scheduled_at   timestamptz default null,
  p_venue          text default null,
  p_notes          text default null
)
returns public.application_appointments
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_app public.application_appointments;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if p_status is null then
    raise exception 'An appointment status is required' using errcode = 'P0001';
  end if;

  update public.application_appointments
     set status = p_status,
         outcome = nullif(btrim(coalesce(p_outcome, '')), ''),
         scheduled_at = coalesce(p_scheduled_at, scheduled_at),
         venue = coalesce(nullif(btrim(coalesce(p_venue, '')), ''), venue),
         notes = nullif(btrim(coalesce(p_notes, '')), ''),
         completed_at = case
                          when p_status in ('completed', 'no_show') then coalesce(completed_at, now())
                          else null
                        end
   where id = p_appointment_id
  returning * into v_app;

  if not found then
    raise exception 'Appointment not found' using errcode = 'P0002';
  end if;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: issue a form request
-- ===========================================================================
create or replace function public.rpc_staff_issue_form_request(p_form_request_id uuid)
returns public.form_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_form  public.form_requests;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  update public.form_requests
     set status = 'issued',
         issued_at = now(),
         issued_by = v_actor
   where id = p_form_request_id
     and status = 'requested'
  returning * into v_form;

  if not found then
    raise exception 'Only a requested form can be issued' using errcode = 'P0001';
  end if;

  return v_form;
end;
$$;

-- ===========================================================================
-- STAFF: convert a form request into a formal application
-- ===========================================================================
create or replace function public.rpc_staff_convert_form_request(
  p_form_request_id uuid,
  p_application_id  uuid
)
returns public.form_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_form public.form_requests;
  v_applicant uuid;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select requested_by into v_applicant from public.form_requests where id = p_form_request_id;
  if not found then
    raise exception 'Form request not found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1 from public.franchise_applications a
     where a.id = p_application_id and a.applicant_id = v_applicant
  ) then
    raise exception 'The application does not belong to the form request applicant'
      using errcode = 'P0001';
  end if;

  update public.form_requests
     set status = 'converted',
         converted_application_id = p_application_id
   where id = p_form_request_id
     and status in ('requested', 'issued')
  returning * into v_form;

  if not found then
    raise exception 'This form request can no longer be converted' using errcode = 'P0001';
  end if;

  return v_form;
end;
$$;

-- ===========================================================================
-- DRIVER: request a form (mobile app)
-- ===========================================================================
create or replace function public.rpc_driver_request_form(p_payload jsonb)
returns public.form_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor  uuid := public.current_profile_id();
  v_role   public.user_role;
  v_type   public.application_type;
  v_toda   uuid;
  v_year   integer := extract(year from now())::int;
  v_seq    integer;
  v_number text;
  v_form   public.form_requests;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_role := public.current_user_role();
  if v_role <> 'driver' then
    raise exception 'Only driver/operator accounts may request a form' using errcode = '42501';
  end if;

  if (p_payload ->> 'application_type') not in ('new', 'renewal') then
    raise exception 'application_type must be either "new" or "renewal"' using errcode = 'P0001';
  end if;
  v_type := (p_payload ->> 'application_type')::public.application_type;

  begin
    v_toda := nullif(btrim(coalesce(p_payload ->> 'toda_id', '')), '')::uuid;
  exception when others then
    raise exception 'The selected TODA is invalid' using errcode = 'P0001';
  end;

  if v_toda is not null
     and not exists (select 1 from public.todas t where t.id = v_toda and t.is_active) then
    raise exception 'The selected TODA is not accredited or is inactive' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.form_requests f
     where f.requested_by = v_actor
       and f.status in ('requested', 'issued')
  ) then
    raise exception 'You already have an open form request' using errcode = 'P0001';
  end if;

  v_seq := public.fn_next_sequence('form_request', v_year);
  v_number := 'FR-' || v_year || '-' || lpad(v_seq::text, 6, '0');

  insert into public.form_requests (
    form_number, requested_by, toda_id, application_type, status, purpose
  )
  values (
    v_number, v_actor, v_toda, v_type, 'requested',
    public.fn_optional_text(p_payload, 'purpose', 500)
  )
  returning * into v_form;

  return v_form;
end;
$$;

-- ===========================================================================
-- DRIVER: cancel an open form request
-- ===========================================================================
create or replace function public.rpc_driver_cancel_form_request(
  p_form_request_id uuid,
  p_reason          text default null
)
returns public.form_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_form  public.form_requests;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.form_requests
     set status = 'cancelled',
         cancelled_at = now(),
         cancel_reason = nullif(btrim(coalesce(p_reason, '')), '')
   where id = p_form_request_id
     and requested_by = v_actor
     and status in ('requested', 'issued')
  returning * into v_form;

  if not found then
    raise exception 'This form request cannot be cancelled' using errcode = 'P0001';
  end if;

  return v_form;
end;
$$;

-- ===========================================================================
-- STAFF: certificate + archive (Phase 1 hardens these to staff only)
-- ===========================================================================
-- Administrators become read-only in Phase 1. Re-create the certificate and
-- archival RPCs so the database rejects an administrator caller, matching the
-- capability matrix the web console now hides.
create or replace function public.rpc_staff_attach_certificate(
  p_record_id    uuid,
  p_storage_path text
)
returns public.franchise_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_record public.franchise_records;
  v_path   text := btrim(coalesce(p_storage_path, ''));
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select * into v_record from public.franchise_records where id = p_record_id for update;
  if not found then
    raise exception 'Franchise record not found' using errcode = 'P0002';
  end if;

  if v_path = ''
     or length(v_path) > 400
     or split_part(v_path, '/', 1) <> v_record.operator_id::text
     or split_part(v_path, '/', 2) = '' then
    raise exception 'Certificates must be stored under the operator folder of the certificates bucket'
      using errcode = 'P0001';
  end if;

  update public.franchise_records
     set certificate_storage_path = v_path,
         certificate_generated_at = now()
   where id = p_record_id
  returning * into v_record;

  return v_record;
end;
$$;

create or replace function public.rpc_staff_archive_franchise_record(
  p_record_id uuid,
  p_reason    text,
  p_archived  boolean default true
)
returns public.franchise_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_record public.franchise_records;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if p_archived and (v_reason is null or length(v_reason) < 5) then
    raise exception 'An archive reason of at least 5 characters is required' using errcode = 'P0001';
  end if;

  update public.franchise_records
     set archived = p_archived,
         archived_at = case when p_archived then now() else null end,
         archived_by = case when p_archived then public.current_profile_id() else null end
   where id = p_record_id
  returning * into v_record;

  if not found then
    raise exception 'Franchise record not found' using errcode = 'P0002';
  end if;

  return v_record;
end;
$$;
