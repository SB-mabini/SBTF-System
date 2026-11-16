-- ===========================================================================
-- MTOP System — the official decision precedes endorsement
--
-- The processing pipeline is re-ordered so that the approving authority
-- decides first:
--
--   ... verified → recorded → for_approval → for_endorsement
--                → ready_for_release → released → completed
--
-- A rejected application becomes terminal at the decision step and can never
-- reach endorsement, release or a franchise record.
--
-- The franchise record is now issued only when the application is APPROVED.
-- Recording an application no longer mints a franchise number, so a later
-- rejection cannot leave a franchise behind.
-- ===========================================================================

-- Pending applications that were waiting for endorsement under the old order
-- now belong in the decision queue: the decision must be recorded before any
-- endorsement can take place.
update public.franchise_applications
   set stage = 'for_approval'
 where status = 'pending'
   and stage = 'for_endorsement';

-- ===========================================================================
-- Internal: issue the franchise record for an application
--
-- The guard makes the rule explicit at the lowest level: a rejected
-- application can never be issued a franchise, whichever RPC attempts it.
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

  if v_app.status = 'rejected' then
    raise exception 'A rejected application cannot be issued a franchise' using errcode = 'P0001';
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
  'Creates the franchise record for an approved application, or returns the existing one. Refuses rejected applications. Internal: called by staff RPCs, never by clients.';

-- ===========================================================================
-- STAFF: record the application in the register → stage "recorded"
--
-- Recording is bookkeeping only. No franchise number is generated here; the
-- franchise is minted by the decision step, and only when approved. Returning
-- the application rather than a record also removes the old side effect from
-- the client contract.
-- ===========================================================================
drop function if exists public.rpc_staff_record_application(uuid);

create function public.rpc_staff_record_application(p_application_id uuid)
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

  if v_app.stage <> 'verified' then
    raise exception 'Only a verified application can be recorded (current stage: %)', v_app.stage
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
    raise exception 'Cannot record yet: % documentary requirement(s) are still unverified',
      v_outstanding using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set stage = 'recorded'
   where id = v_app.id
  returning * into v_app;

  return v_app;
end;
$$;

comment on function public.rpc_staff_record_application(uuid) is
  'Records a verified application in the register. Does not issue a franchise; that happens only on approval.';

grant execute on function public.rpc_staff_record_application(uuid) to authenticated;

-- ===========================================================================
-- STAFF: forward a recorded application to the approving authority
-- ===========================================================================
create or replace function public.rpc_staff_forward_for_approval(p_application_id uuid)
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

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  if v_app.stage <> 'recorded' then
    raise exception 'Only a recorded application can be forwarded for approval (current stage: %)',
      v_app.stage using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set stage = 'for_approval'
   where id = v_app.id
  returning * into v_app;

  return v_app;
end;
$$;

comment on function public.rpc_staff_forward_for_approval(uuid) is
  'Moves a recorded application into the approval queue. Endorsement is recorded only after the decision.';

grant execute on function public.rpc_staff_forward_for_approval(uuid) to authenticated;

-- ===========================================================================
-- STAFF: record the externally-made decision
--   approved → status approved, stage for_endorsement (issues the franchise)
--   rejected → status rejected, stage rejected (reason mandatory, no franchise)
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

  if v_app.stage <> 'for_approval' then
    raise exception 'Only an application awaiting approval can be decided (current stage: %)',
      v_app.stage using errcode = 'P0001';
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
           stage = 'for_endorsement',
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

comment on function public.rpc_staff_record_decision(uuid, text, text, text, text) is
  'Records the official decision before endorsement. Approval issues the franchise; rejection is terminal and never issues one.';

-- ===========================================================================
-- STAFF: record an endorsement/transmittal → stage "ready_for_release"
--
-- An endorsement can only follow an approved decision. It no longer moves the
-- application to approval; the decision already happened.
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

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'approved' then
    raise exception 'Only an approved application can be endorsed (current status: %)',
      v_app.status using errcode = 'P0001';
  end if;

  if v_app.stage <> 'for_endorsement' then
    raise exception 'Only an application awaiting endorsement can be endorsed (current stage: %)',
      v_app.stage using errcode = 'P0001';
  end if;

  update public.franchise_applications
     set stage = 'ready_for_release',
         endorsed_to = v_endorsed,
         endorsement_reference = v_reference,
         endorsed_at = now(),
         endorsed_by = v_actor
   where id = v_app.id
  returning * into v_app;

  return v_app;
end;
$$;

comment on function public.rpc_staff_record_endorsement(uuid, text, text, text) is
  'Records the endorsement of an already approved application and makes it ready for release. Rejected applications cannot be endorsed.';

-- ===========================================================================
-- STAFF: approve an application (compatibility RPC)
--
-- Still supported for callers that do not capture the approving authority. It
-- follows the same order: approval first, endorsement next. The franchise is
-- issued here, never at recording.
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
         stage = 'for_endorsement',
         reviewed_by = v_actor,
         reviewed_at = now(),
         rejection_reason = null,
         decision_recorded_at = coalesce(decision_recorded_at, now())
   where id = v_app.id;

  return v_record;
end;
$$;

comment on function public.rpc_staff_approve_application(uuid) is
  'Approves a fully verified application and issues a franchise record (staff only). The application then awaits endorsement. Prefer rpc_staff_record_decision() to also capture the approving authority.';

-- ===========================================================================
-- STAFF: release the certificate/document → stage "released"
--
-- The endorsement must be on record first, so a release cannot skip the
-- re-ordered pipeline.
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

  if v_app.stage in ('released', 'completed') then
    raise exception 'This application has already been released' using errcode = 'P0001';
  end if;

  if v_app.stage <> 'ready_for_release' then
    raise exception 'Record the endorsement before releasing the franchise (current stage: %)',
      v_app.stage using errcode = 'P0001';
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

comment on function public.rpc_staff_release_document(uuid, text, text, text, text) is
  'Records the physical release of an approved, endorsed franchise document (staff only).';
