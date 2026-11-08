-- ===========================================================================
-- SBTF System — Request-form-first workflow (part 3 of 3)
-- RPCs: submit a complete request, edit/resubmit a rejected request, staff
-- approve/reject/print, the staff review-deadline monitor, and the hard gate
-- in rpc_driver_submit_application().
-- ===========================================================================

-- --- policy helpers ---------------------------------------------------------
create or replace function public.fn_form_request_review_days()
returns integer
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_value numeric;
begin
  select (value #>> '{}')::numeric into v_value
    from public.system_settings
   where key = 'form_request_review_days';

  v_value := coalesce(v_value, 3);
  if v_value < 1 then
    v_value := 1;
  elsif v_value > 3 then
    v_value := 3;
  end if;

  return v_value::integer;
end;
$$;

create or replace function public.fn_form_request_review_reminder_hours()
returns integer
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_value numeric;
begin
  select (value #>> '{}')::numeric into v_value
    from public.system_settings
   where key = 'form_request_review_reminder_hours';

  v_value := coalesce(v_value, 12);
  if v_value < 1 then
    v_value := 1;
  end if;

  return v_value::integer;
end;
$$;

create or replace function public.fn_form_request_signature_required()
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_value boolean;
begin
  select (value #>> '{}')::boolean into v_value
    from public.system_settings
   where key = 'form_request_signature_required';

  return coalesce(v_value, true);
end;
$$;

create or replace function public.fn_form_request_allow_typed_signature()
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_value boolean;
begin
  select (value #>> '{}')::boolean into v_value
    from public.system_settings
   where key = 'form_request_allow_typed_signature';

  return coalesce(v_value, true);
end;
$$;

-- --- duplicate vehicle guard ------------------------------------------------
create or replace function public.fn_assert_vehicle_available(
  p_actor                     uuid,
  p_plate_number              text,
  p_engine_number             text,
  p_chassis_number            text,
  p_exclude_record_id         uuid default null,
  p_exclude_application_id    uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1
      from public.franchise_records r
      join public.franchise_applications a on a.id = r.application_id
     where r.archived = false
       and r.id is distinct from p_exclude_record_id
       and (
         upper(btrim(a.plate_number))   = upper(btrim(p_plate_number))
         or upper(btrim(a.engine_number))  = upper(btrim(p_engine_number))
         or upper(btrim(a.chassis_number)) = upper(btrim(p_chassis_number))
       )
  ) then
    raise exception 'This vehicle (plate, engine or chassis number) is already covered by an active franchise record'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
      from public.franchise_applications a
     where a.status = 'pending'
       and a.id is distinct from p_exclude_application_id
       and a.applicant_id <> p_actor
       and (
         upper(btrim(a.plate_number))   = upper(btrim(p_plate_number))
         or upper(btrim(a.engine_number))  = upper(btrim(p_engine_number))
         or upper(btrim(a.chassis_number)) = upper(btrim(p_chassis_number))
       )
  ) then
    raise exception 'Another pending application already uses this vehicle (plate, engine or chassis number)'
      using errcode = 'P0001';
  end if;
end;
$$;

-- --- payload normaliser -----------------------------------------------------
-- Validates and normalises every field of a request. Shared by create and
-- resubmit so the rules cannot drift apart.
create or replace function public.fn_normalize_form_request_payload(
  p_actor   uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_type      text;
  v_toda      uuid;
  v_ctc       text;
  v_make      text;
  v_model     text;
  v_engine    text;
  v_chassis   text;
  v_plate     text;
  v_cr        text;
  v_path      text;
  v_file_name text;
  v_mime      text;
  v_size      integer;
  v_sig_path  text;
  v_sig_typed text;
begin
  v_type := p_payload ->> 'application_type';
  if v_type not in ('new', 'renewal') then
    raise exception 'application_type must be either "new" or "renewal"' using errcode = 'P0001';
  end if;

  begin
    v_toda := nullif(btrim(coalesce(p_payload ->> 'toda_id', '')), '')::uuid;
  exception when others then
    raise exception 'The selected TODA is invalid' using errcode = 'P0001';
  end;

  if v_toda is null then
    raise exception 'A TODA must be selected' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.todas t where t.id = v_toda and t.is_active) then
    raise exception 'The selected TODA is not accredited or is inactive' using errcode = 'P0001';
  end if;

  v_ctc := public.fn_required_text(p_payload, 'ctc_number', 1, 40);
  v_make := public.fn_required_text(p_payload, 'vehicle_make', 1, 60);
  v_model := public.fn_required_text(p_payload, 'vehicle_model', 1, 60);
  v_engine := public.fn_required_text(p_payload, 'engine_number', 3, 40);
  v_chassis := public.fn_required_text(p_payload, 'chassis_number', 3, 40);
  v_plate := upper(public.fn_required_text(p_payload, 'plate_number', 3, 20));
  v_cr := public.fn_required_text(p_payload, 'cr_number', 1, 60);

  v_path := public.fn_required_text(p_payload, 'or_cr_storage_path', 3, 400);
  v_file_name := coalesce(public.fn_optional_text(p_payload, 'or_cr_file_name', 200), 'or-cr');
  v_mime := coalesce(p_payload ->> 'or_cr_mime_type', '');
  begin
    v_size := (p_payload ->> 'or_cr_file_size_bytes')::integer;
  exception when others then
    v_size := null;
  end;

  if v_path not like p_actor::text || '/%' then
    raise exception 'OR/CR files must be uploaded to your own storage folder'
      using errcode = '42501';
  end if;

  if v_mime not in ('application/pdf', 'image/jpeg', 'image/png') then
    raise exception 'The OR/CR file must be a PDF, JPEG or PNG' using errcode = 'P0001';
  end if;

  if v_size is null or v_size < 1 or v_size > 10485760 then
    raise exception 'The OR/CR file must not exceed 10 MB' using errcode = 'P0001';
  end if;

  v_sig_path := public.fn_optional_text(p_payload, 'signature_storage_path', 400);
  v_sig_typed := public.fn_optional_text(p_payload, 'signature_typed_name', 120);

  if v_sig_path is not null and v_sig_path not like p_actor::text || '/%' then
    raise exception 'Signature files must be uploaded to your own storage folder'
      using errcode = '42501';
  end if;

  if public.fn_form_request_signature_required()
     and v_sig_path is null
     and v_sig_typed is null then
    raise exception 'A signature is required' using errcode = 'P0001';
  end if;

  if v_sig_path is null
     and v_sig_typed is not null
     and not public.fn_form_request_allow_typed_signature() then
    raise exception 'A drawn signature is required (typed signatures are disabled)'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'application_type', v_type,
    'toda_id', v_toda,
    'purpose', public.fn_optional_text(p_payload, 'purpose', 500),
    'ctc_number', v_ctc,
    'vehicle_make', v_make,
    'vehicle_model', v_model,
    'engine_number', v_engine,
    'chassis_number', v_chassis,
    'plate_number', v_plate,
    'cr_number', v_cr,
    'or_cr_storage_path', v_path,
    'or_cr_file_name', v_file_name,
    'or_cr_mime_type', v_mime,
    'or_cr_file_size_bytes', v_size,
    'signature_storage_path', v_sig_path,
    'signature_typed_name', v_sig_typed
  );
end;
$$;

-- ===========================================================================
-- DRIVER: submit a complete form request
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
  v_data   jsonb;
  v_name   text;
  v_phone  text;
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

  if exists (
    select 1 from public.form_requests f
     where f.requested_by = v_actor
       and f.status in ('requested', 'issued')
  ) then
    raise exception 'You already have an open form request' using errcode = 'P0001';
  end if;

  v_data := public.fn_normalize_form_request_payload(v_actor, p_payload);

  select full_name, contact_number into v_name, v_phone
    from public.profiles where id = v_actor;

  v_seq := public.fn_next_sequence('form_request', v_year);
  v_number := 'FR-' || v_year || '-' || lpad(v_seq::text, 6, '0');

  insert into public.form_requests (
    form_number, requested_by, toda_id, application_type, status, purpose,
    applicant_name, contact_number, ctc_number,
    vehicle_make, vehicle_model, engine_number, chassis_number, plate_number, cr_number,
    or_cr_storage_path, or_cr_file_name, or_cr_mime_type, or_cr_file_size_bytes,
    signature_storage_path, signature_typed_name,
    acknowledged_at, review_due_at
  )
  values (
    v_number, v_actor,
    (v_data ->> 'toda_id')::uuid,
    (v_data ->> 'application_type')::public.application_type,
    'requested',
    v_data ->> 'purpose',
    v_name, v_phone, v_data ->> 'ctc_number',
    v_data ->> 'vehicle_make', v_data ->> 'vehicle_model',
    v_data ->> 'engine_number', v_data ->> 'chassis_number',
    v_data ->> 'plate_number', v_data ->> 'cr_number',
    v_data ->> 'or_cr_storage_path', v_data ->> 'or_cr_file_name',
    v_data ->> 'or_cr_mime_type', (v_data ->> 'or_cr_file_size_bytes')::integer,
    v_data ->> 'signature_storage_path', v_data ->> 'signature_typed_name',
    now(),
    now() + make_interval(days => public.fn_form_request_review_days())
  )
  returning * into v_form;

  return v_form;
end;
$$;

-- ===========================================================================
-- DRIVER: edit and resubmit a REJECTED request (same row)
-- ===========================================================================
create or replace function public.rpc_driver_update_form_request(
  p_form_request_id uuid,
  p_payload         jsonb
)
returns public.form_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_form  public.form_requests;
  v_data  jsonb;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_form
    from public.form_requests
   where id = p_form_request_id
   for update;

  if not found then
    raise exception 'Form request not found' using errcode = 'P0002';
  end if;

  if v_form.requested_by <> v_actor then
    raise exception 'You may only edit your own form request' using errcode = '42501';
  end if;

  if v_form.status <> 'rejected' then
    raise exception 'Only a rejected form request can be edited and resubmitted'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.form_requests f
     where f.requested_by = v_actor
       and f.id <> p_form_request_id
       and f.status in ('requested', 'issued')
  ) then
    raise exception 'You already have another open form request' using errcode = 'P0001';
  end if;

  v_data := public.fn_normalize_form_request_payload(v_actor, p_payload);

  update public.form_requests
     set toda_id = (v_data ->> 'toda_id')::uuid,
         application_type = (v_data ->> 'application_type')::public.application_type,
         status = 'requested',
         purpose = v_data ->> 'purpose',
         ctc_number = v_data ->> 'ctc_number',
         vehicle_make = v_data ->> 'vehicle_make',
         vehicle_model = v_data ->> 'vehicle_model',
         engine_number = v_data ->> 'engine_number',
         chassis_number = v_data ->> 'chassis_number',
         plate_number = v_data ->> 'plate_number',
         cr_number = v_data ->> 'cr_number',
         or_cr_storage_path = v_data ->> 'or_cr_storage_path',
         or_cr_file_name = v_data ->> 'or_cr_file_name',
         or_cr_mime_type = v_data ->> 'or_cr_mime_type',
         or_cr_file_size_bytes = (v_data ->> 'or_cr_file_size_bytes')::integer,
         signature_storage_path = v_data ->> 'signature_storage_path',
         signature_typed_name = v_data ->> 'signature_typed_name',
         acknowledged_at = coalesce(acknowledged_at, now()),
         reviewed_by = null,
         reviewed_at = null,
         rejection_reason = null,
         review_due_at = now() + make_interval(days => public.fn_form_request_review_days()),
         review_reminder_sent_at = null,
         review_overdue_notified_at = null
   where id = p_form_request_id
  returning * into v_form;

  return v_form;
end;
$$;

-- ===========================================================================
-- STAFF: approve and issue a form request
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
         issued_by = v_actor,
         reviewed_by = v_actor,
         reviewed_at = now(),
         rejection_reason = null,
         acknowledged_at = coalesce(acknowledged_at, requested_at)
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
-- STAFF: reject a form request with a reason
-- ===========================================================================
create or replace function public.rpc_staff_reject_form_request(
  p_form_request_id uuid,
  p_reason          text
)
returns public.form_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor  uuid := public.current_profile_id();
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_form   public.form_requests;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if v_reason is null or length(v_reason) < 10 or length(v_reason) > 1000 then
    raise exception 'A rejection reason between 10 and 1000 characters is required'
      using errcode = 'P0001';
  end if;

  update public.form_requests
     set status = 'rejected',
         reviewed_by = v_actor,
         reviewed_at = now(),
         rejection_reason = v_reason,
         acknowledged_at = coalesce(acknowledged_at, requested_at)
   where id = p_form_request_id
     and status = 'requested'
  returning * into v_form;

  if not found then
    raise exception 'Only a requested form can be rejected' using errcode = 'P0001';
  end if;

  return v_form;
end;
$$;

-- ===========================================================================
-- STAFF: record that the approved letter was printed / claimed
-- ===========================================================================
create or replace function public.rpc_staff_mark_form_request_printed(p_form_request_id uuid)
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
     set printed_at = now(),
         printed_by = v_actor
   where id = p_form_request_id
     and status in ('issued', 'converted')
  returning * into v_form;

  if not found then
    raise exception 'Only an issued form can be marked as printed' using errcode = 'P0001';
  end if;

  perform public.fn_log_activity(
    v_actor,
    'form_request_printed',
    'form_request',
    v_form.id,
    jsonb_build_object('form_number', v_form.form_number)
  );

  return v_form;
end;
$$;

-- ===========================================================================
-- STAFF: review-deadline monitor (does not change request status)
-- ===========================================================================
create or replace function public.fn_check_form_request_review_sla()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reminders integer := 0;
  v_overdue   integer := 0;
  v_row       record;
  v_hours     integer := public.fn_form_request_review_reminder_hours();
begin
  -- Reminder: due soon but not yet overdue.
  for v_row in
    select f.id, f.form_number, f.review_due_at
      from public.form_requests f
     where f.status = 'requested'
       and f.review_due_at is not null
       and f.review_reminder_sent_at is null
       and f.review_due_at > now()
       and f.review_due_at <= now() + make_interval(hours => v_hours)
     for update skip locked
  loop
    update public.form_requests
       set review_reminder_sent_at = now()
     where id = v_row.id;

    perform public.fn_notify_staff_and_admin(
      'Form request review due soon',
      'Form request ' || v_row.form_number || ' is due for review by ' ||
        to_char(v_row.review_due_at, 'FMMon FMDD, YYYY FMHH12:MI AM') || '.',
      'form_request_review_reminder',
      'form_request',
      v_row.id
    );

    v_reminders := v_reminders + 1;
  end loop;

  -- Overdue: past the deadline. Status is intentionally left at 'requested'.
  for v_row in
    select f.id, f.form_number, f.review_due_at
      from public.form_requests f
     where f.status = 'requested'
       and f.review_due_at is not null
       and f.review_due_at < now()
       and f.review_overdue_notified_at is null
     for update skip locked
  loop
    update public.form_requests
       set review_overdue_notified_at = now()
     where id = v_row.id;

    perform public.fn_log_activity(
      null,
      'form_request_review_overdue',
      'form_request',
      v_row.id,
      jsonb_build_object('form_number', v_row.form_number, 'review_due_at', v_row.review_due_at)
    );

    perform public.fn_notify_staff_and_admin(
      'Form request review overdue',
      'Form request ' || v_row.form_number || ' has passed its review deadline of ' ||
        to_char(v_row.review_due_at, 'FMMon FMDD, YYYY FMHH12:MI AM') || '.',
      'form_request_review_overdue',
      'form_request',
      v_row.id
    );

    v_overdue := v_overdue + 1;
  end loop;

  return jsonb_build_object('reminders', v_reminders, 'overdue', v_overdue);
end;
$$;

-- ===========================================================================
-- DRIVER: submit a new or renewal franchise application (request-gated)
-- ===========================================================================
create or replace function public.rpc_driver_submit_application(p_payload jsonb)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor        uuid := public.current_profile_id();
  v_role         public.user_role;
  v_profile      public.profiles;
  v_form         public.form_requests;
  v_type         public.application_type;
  v_toda_id      uuid;
  v_barangay     text;
  v_record       public.franchise_records;
  v_app          public.franchise_applications;
  v_documents    jsonb;
  v_doc          jsonb;
  v_year         integer := extract(year from now())::int;
  v_seq          integer;
  v_app_number   text;
  v_expected     integer;
  v_provided     integer;
  v_missing      text;
  v_vehicle_year integer;
  v_capacity     integer;
  v_client_orcr  boolean := false;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_role := public.current_user_role();
  if v_role <> 'driver' then
    raise exception 'Only driver/operator accounts may submit franchise applications'
      using errcode = '42501';
  end if;

  if (p_payload ->> 'application_type') not in ('new', 'renewal') then
    raise exception 'application_type must be either "new" or "renewal"' using errcode = 'P0001';
  end if;
  v_type := (p_payload ->> 'application_type')::public.application_type;

  -- ---- hard gate: a staff-approved request for this application type -------
  select * into v_form
    from public.form_requests
   where requested_by = v_actor
     and status = 'issued'
     and application_type = v_type
   order by issued_at desc nulls last
   limit 1
   for update;

  if v_form.id is null then
    if exists (select 1 from public.form_requests
                where requested_by = v_actor and status = 'requested') then
      raise exception 'Your form request is still waiting for staff approval.'
        using errcode = 'P0001';
    elsif exists (select 1 from public.form_requests
                   where requested_by = v_actor and status = 'rejected') then
      raise exception 'Your form request was rejected. Edit and resubmit it before applying.'
        using errcode = 'P0001';
    else
      raise exception 'Submit a form request and get it approved by staff before applying.'
        using errcode = 'P0001';
    end if;
  end if;

  -- ---- authoritative values come from the approved request -----------------
  v_toda_id := coalesce(v_form.toda_id, nullif(btrim(coalesce(p_payload ->> 'toda_id', '')), '')::uuid);

  if v_toda_id is null then
    raise exception 'A TODA must be selected' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.todas t where t.id = v_toda_id and t.is_active) then
    raise exception 'The selected TODA is not accredited or is inactive' using errcode = 'P0001';
  end if;

  v_barangay := public.fn_optional_text(p_payload, 'operator_barangay_code', 20);
  if v_barangay is not null and not exists (select 1 from public.barangays b where b.code = v_barangay) then
    raise exception 'Unknown barangay code' using errcode = 'P0001';
  end if;

  begin
    v_vehicle_year := (p_payload ->> 'vehicle_year')::integer;
    v_capacity := coalesce((p_payload ->> 'seating_capacity')::integer, 5);
  exception when others then
    raise exception 'Vehicle year and seating capacity must be numeric' using errcode = 'P0001';
  end;

  if v_vehicle_year < 1950 or v_vehicle_year > v_year + 1 then
    raise exception 'Vehicle year must be between 1950 and %', v_year + 1 using errcode = 'P0001';
  end if;

  if v_capacity < 1 or v_capacity > 12 then
    raise exception 'Seating capacity must be between 1 and 12' using errcode = 'P0001';
  end if;

  -- ---- renewal / new franchise rules ---------------------------------------
  if v_type = 'renewal' then
    begin
      select * into v_record
        from public.franchise_records
       where id = (p_payload ->> 'renewal_of_record_id')::uuid;
    exception when others then
      raise exception 'A valid franchise record must be referenced for a renewal'
        using errcode = 'P0001';
    end;

    if v_record.id is null then
      raise exception 'Franchise record not found' using errcode = 'P0001';
    end if;

    if v_record.operator_id <> v_actor then
      raise exception 'You may only renew your own franchise record' using errcode = '42501';
    end if;

    if v_record.archived then
      raise exception 'This franchise record is archived and can no longer be renewed'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1 from public.franchise_applications a
       where a.renewal_of_record_id = v_record.id and a.status = 'pending'
    ) then
      raise exception 'A renewal application for this franchise is already pending'
        using errcode = 'P0001';
    end if;
  else
    if exists (
      select 1 from public.franchise_applications a
       where a.applicant_id = v_actor and a.application_type = 'new' and a.status = 'pending'
    ) then
      raise exception 'You already have a pending new franchise application'
        using errcode = 'P0001';
    end if;
  end if;

  perform public.fn_assert_vehicle_available(
    v_actor,
    v_form.plate_number,
    v_form.engine_number,
    v_form.chassis_number,
    case when v_type = 'renewal' then v_record.id else null end,
    null
  );

  -- ---- documents: the request supplies the OR/CR ---------------------------
  v_documents := p_payload -> 'documents';
  if v_documents is null or jsonb_typeof(v_documents) <> 'array' then
    raise exception 'documents must be an array of uploaded documentary requirements'
      using errcode = 'P0001';
  end if;

  v_client_orcr := exists (
    select 1 from jsonb_array_elements(v_documents) d
     where d ->> 'document_type' = 'or_cr'
  );

  if v_form.or_cr_storage_path is not null and v_client_orcr then
    raise exception 'The OR/CR is attached automatically from your approved request; do not upload it again'
      using errcode = 'P0001';
  end if;

  if v_form.or_cr_storage_path is null and not v_client_orcr then
    raise exception 'The approved request has no OR/CR on file. Ask staff to return it for completion.'
      using errcode = 'P0001';
  end if;

  -- When the server owns the OR/CR, the client must supply the other three.
  v_expected := case when v_form.or_cr_storage_path is not null
                     then (select count(*) from unnest(enum_range(null::public.document_type)) dt
                            where dt::text <> 'or_cr')
                     else (select count(*) from unnest(enum_range(null::public.document_type))) end;

  v_provided := (
    select count(distinct (d ->> 'document_type')::public.document_type)
      from jsonb_array_elements(v_documents) d
     where (d ->> 'document_type') in (select dt::text from unnest(enum_range(null::public.document_type)) dt)
       and (v_form.or_cr_storage_path is null or (d ->> 'document_type') <> 'or_cr')
  );

  if v_provided <> v_expected then
    raise exception 'This application needs % documentary requirement(s); received %',
      v_expected, coalesce(v_provided, 0) using errcode = 'P0001';
  end if;

  select string_agg(dt::text, ', ') into v_missing
    from unnest(enum_range(null::public.document_type)) as dt
   where (v_form.or_cr_storage_path is null or dt::text <> 'or_cr')
     and not exists (
           select 1 from jsonb_array_elements(v_documents) d
            where d ->> 'document_type' = dt::text
         );
  if v_missing is not null then
    raise exception 'Missing documentary requirement(s): %', v_missing using errcode = 'P0001';
  end if;

  if exists (
    select 1 from jsonb_array_elements(v_documents) d
     where (d ->> 'storage_path') is null
        or (d ->> 'storage_path') not like v_actor::text || '/%'
  ) then
    raise exception 'Document files must be uploaded to your own storage folder'
      using errcode = '42501';
  end if;

  if exists (
    select 1 from jsonb_array_elements(v_documents) d
     where coalesce(d ->> 'mime_type', '') not in ('application/pdf', 'image/jpeg', 'image/png')
  ) then
    raise exception 'Documents must be PDF, JPEG or PNG files' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from jsonb_array_elements(v_documents) d
     where coalesce((d ->> 'file_size_bytes')::bigint, 0) > 10485760
  ) then
    raise exception 'Each document must not exceed 10 MB' using errcode = 'P0001';
  end if;

  select * into v_profile from public.profiles where id = v_actor;

  -- ---- create the application (vehicle + operator from the request) --------
  v_seq := public.fn_next_sequence('application', v_year);
  v_app_number := 'APP-' || v_year || '-' || lpad(v_seq::text, 6, '0');

  insert into public.franchise_applications (
    application_number, applicant_id, application_type, status, toda_id,
    operator_first_name, operator_middle_name, operator_last_name,
    operator_contact_number, operator_address_line, operator_barangay_code, operator_email,
    vehicle_make, vehicle_model, vehicle_year, vehicle_color,
    plate_number, engine_number, chassis_number, seating_capacity, mtop_number, body_number,
    renewal_of_record_id, remarks, submitted_at
  )
  values (
    v_app_number, v_actor, v_type, 'pending', v_toda_id,
    v_profile.first_name, v_profile.middle_name, v_profile.last_name,
    coalesce(nullif(btrim(coalesce(v_form.contact_number, '')), ''), v_profile.contact_number),
    public.fn_required_text(p_payload, 'operator_address_line', 5, 200),
    v_barangay,
    public.fn_optional_text(p_payload, 'operator_email', 160),
    v_form.vehicle_make,
    v_form.vehicle_model,
    v_vehicle_year,
    public.fn_required_text(p_payload, 'vehicle_color', 2, 40),
    upper(v_form.plate_number),
    upper(v_form.engine_number),
    upper(v_form.chassis_number),
    v_capacity,
    public.fn_optional_text(p_payload, 'mtop_number', 60),
    public.fn_optional_text(p_payload, 'body_number', 60),
    case when v_type = 'renewal' then v_record.id else null end,
    public.fn_optional_text(p_payload, 'remarks', 1000),
    now()
  )
  returning * into v_app;

  -- Attach the client-supplied documents.
  for v_doc in select * from jsonb_array_elements(v_documents)
  loop
    insert into public.franchise_documents (
      application_id, document_type, storage_path, file_name, file_size_bytes, mime_type
    )
    values (
      v_app.id,
      (v_doc ->> 'document_type')::public.document_type,
      v_doc ->> 'storage_path',
      coalesce(public.fn_optional_text(v_doc, 'file_name', 200), 'document'),
      coalesce((v_doc ->> 'file_size_bytes')::integer, null),
      coalesce(v_doc ->> 'mime_type', null)
    );
  end loop;

  -- Attach the OR/CR from the approved request when the server owns it.
  if v_form.or_cr_storage_path is not null then
    insert into public.franchise_documents (
      application_id, document_type, storage_path, file_name, file_size_bytes, mime_type
    )
    values (
      v_app.id, 'or_cr', v_form.or_cr_storage_path,
      coalesce(v_form.or_cr_file_name, 'or-cr'),
      v_form.or_cr_file_size_bytes,
      v_form.or_cr_mime_type
    );
  end if;

  update public.profiles
     set toda_id = coalesce(toda_id, v_toda_id)
   where id = v_actor;

  -- Consume the approved request atomically.
  update public.form_requests
     set status = 'converted',
         converted_application_id = v_app.id
   where id = v_form.id;

  return v_app;
end;
$$;

comment on function public.rpc_driver_submit_application(jsonb) is
  'Driver/operator submits a new or renewal franchise application. Requires a staff-approved form request of the same type; the request supplies vehicle identity and OR/CR, and is consumed atomically.';

-- --- scheduled review-deadline monitor --------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'sbtf-form-request-review-sla') then
      perform cron.unschedule('sbtf-form-request-review-sla');
    end if;

    perform cron.schedule(
      'sbtf-form-request-review-sla',
      '5 * * * *',
      $cron$select public.fn_check_form_request_review_sla()$cron$
    );

    raise notice 'Scheduled job sbtf-form-request-review-sla created (hourly at :05).';
  else
    raise notice 'Scheduled job skipped: pg_cron is not enabled on this database.';
  end if;
end
$$;

-- --- privileges -------------------------------------------------------------
grant execute on function public.rpc_driver_request_form(jsonb) to authenticated;
grant execute on function public.rpc_driver_update_form_request(uuid, jsonb) to authenticated;
grant execute on function public.rpc_staff_issue_form_request(uuid) to authenticated;
grant execute on function public.rpc_staff_reject_form_request(uuid, text) to authenticated;
grant execute on function public.rpc_staff_mark_form_request_printed(uuid) to authenticated;
grant execute on function public.rpc_staff_convert_form_request(uuid, uuid) to authenticated;
grant execute on function public.rpc_driver_submit_application(jsonb) to authenticated;

revoke all on function public.fn_form_request_review_days() from public, anon, authenticated;
revoke all on function public.fn_form_request_review_reminder_hours() from public, anon, authenticated;
revoke all on function public.fn_form_request_signature_required() from public, anon, authenticated;
revoke all on function public.fn_form_request_allow_typed_signature() from public, anon, authenticated;
revoke all on function public.fn_assert_vehicle_available(uuid, text, text, text, uuid, uuid) from public, anon, authenticated;
revoke all on function public.fn_normalize_form_request_payload(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.fn_check_form_request_review_sla() from public, anon, authenticated;
