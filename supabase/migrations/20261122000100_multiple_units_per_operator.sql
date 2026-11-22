-- ===========================================================================
-- MTOP System — multiple tricycles under one operator account
--
-- An operator may hold more than one franchise, one per tricycle. The schema
-- already models that (franchise_records.operator_id is not unique), but two
-- convenience guards limited each ACCOUNT to one request/application at a
-- time, and application submission picked a request by type alone. Those three
-- assumptions are replaced here:
--
--   * an operator may have several open form requests, as long as each one is
--     for a different vehicle (the vehicle identity guard is unchanged);
--   * an operator may have several pending new applications, again one per
--     vehicle;
--   * `rpc_driver_submit_application` accepts `form_request_id` in its payload
--     and consumes exactly that approved request. When an older client omits
--     it, submission still works if the operator has exactly one approved
--     request of that type; with several it is refused so the vehicle cannot
--     be mixed up.
--
-- Renewal is unaffected: it already targets a specific `renewal_of_record_id`
-- and the per-record pending guard remains.
-- ===========================================================================

-- --- remove the account-wide unique request slot ---------------------------
-- Some projects carry a partial unique index that allowed only one open
-- request per account (`form_requests_one_open_per_driver`). It is not part of
-- any migration in this repository, but when present it silently overrides the
-- per-vehicle rule below, so remove it. The per-vehicle duplicate guard in
-- `fn_assert_form_request_vehicle_available` remains the authority.
drop index if exists public.form_requests_one_open_per_driver;

-- --- pending applications claim a vehicle regardless of who filed them ------
-- Previously the same actor's pending application was excluded, because the
-- per-account "only one pending new application" rule covered it. With several
-- units allowed, a pending application must claim its vehicle for everyone,
-- including the operator who filed it.
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
       and (
         upper(btrim(a.plate_number))   = upper(btrim(p_plate_number))
         or upper(btrim(a.engine_number))  = upper(btrim(p_engine_number))
         or upper(btrim(a.chassis_number)) = upper(btrim(p_chassis_number))
       )
  ) then
    raise exception 'A pending application already uses this vehicle (plate, engine or chassis number)'
      using errcode = 'P0001';
  end if;
end;
$$;

-- --- driver: request a form (several vehicles per account) -------------------
-- Same as migration 20261116000100 except the account-wide "one open request"
-- guard is gone. `fn_normalize_form_request_payload` still refuses a request
-- whose plate, engine, chassis or CR number is already on an open request or a
-- pending application, so the open-request rule is now per vehicle.
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
  v_opens  timestamptz;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_role := public.current_user_role();
  if v_role <> 'driver' then
    raise exception 'Only driver/operator accounts may request a form' using errcode = '42501';
  end if;

  -- ---- renewal eligibility: at least one own, non-archived record in window
  if (p_payload ->> 'application_type') = 'renewal' then
    if not exists (
      select 1
        from public.franchise_records fr
       where fr.operator_id = v_actor
         and fr.archived = false
         and public.fn_renewal_is_open(fr.expires_at)
    ) then
      select min(public.fn_renewal_opens_at(fr.expires_at))
        into v_opens
        from public.franchise_records fr
       where fr.operator_id = v_actor
         and fr.archived = false;

      if v_opens is null then
        raise exception 'You have no franchise available to renew.'
          using errcode = 'P0001';
      end if;

      raise exception 'Renewal opens on % — you can renew from 30 days before a franchise expires',
        to_char(v_opens, 'FMMonth FMDD, YYYY')
        using errcode = 'P0001';
    end if;
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

-- --- driver: edit and resubmit a REJECTED request ---------------------------
-- Same as migration 20261107000400 except the account-wide "another open
-- request" guard is gone. The normaliser still refuses a resubmission that
-- would duplicate another open request's vehicle.
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

-- --- driver: submit a new or renewal application (per vehicle) --------------
-- Same as migration 20261116000100 with two changes:
--   * the request is selected by `form_request_id` when supplied, otherwise
--     only when it is the operator's sole approved request of that type;
--   * the "one pending new application per account" rule is replaced by a
--     per-vehicle pending check.
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
  v_form_id      uuid;
  v_issued_count integer;
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
  begin
    v_form_id := nullif(btrim(coalesce(p_payload ->> 'form_request_id', '')), '')::uuid;
  exception when others then
    raise exception 'The selected form request is invalid' using errcode = 'P0001';
  end;

  if v_form_id is not null then
    -- The client named the tricycle's request: use exactly that row.
    select * into v_form
      from public.form_requests
     where id = v_form_id
       and requested_by = v_actor
       and status = 'issued'
       and application_type = v_type
     for update;

    if not found then
      raise exception 'That approved form request is not available for this application'
        using errcode = 'P0001';
    end if;
  else
    select count(*) into v_issued_count
      from public.form_requests
     where requested_by = v_actor
       and status = 'issued'
       and application_type = v_type;

    if v_issued_count = 0 then
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
    elsif v_issued_count > 1 then
      raise exception 'You have more than one approved form request. Choose which tricycle this application is for.'
        using errcode = 'P0001';
    else
      select * into v_form
        from public.form_requests
       where requested_by = v_actor
         and status = 'issued'
         and application_type = v_type
       for update;
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

    -- ---- 30-day renewal window (server-enforced) ---------------------------
    if not public.fn_renewal_is_open(v_record.expires_at) then
      raise exception 'Renewal opens on % — you can renew from 30 days before the franchise expires',
        to_char(public.fn_renewal_opens_at(v_record.expires_at), 'FMMonth FMDD, YYYY')
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
    -- One pending new application per VEHICLE, not per account.
    if exists (
      select 1 from public.franchise_applications a
       where a.status = 'pending'
         and (
           upper(btrim(a.plate_number))    = upper(btrim(v_form.plate_number))
           or upper(btrim(a.engine_number))  = upper(btrim(v_form.engine_number))
           or upper(btrim(a.chassis_number)) = upper(btrim(v_form.chassis_number))
         )
    ) then
      raise exception 'This tricycle already has a pending franchise application'
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

  -- Consume exactly the approved request used above.
  update public.form_requests
     set status = 'converted',
         converted_application_id = v_app.id
   where id = v_form.id;

  return v_app;
end;
$$;

comment on function public.rpc_driver_submit_application(jsonb) is
  'Driver/operator submits a new or renewal franchise application. Requires a staff-approved form request of the same type; the selected form_request_id (or the sole approved request) supplies vehicle identity and OR/CR, and is consumed atomically. Multiple applications per operator are allowed, one per vehicle.';

-- --- privileges -------------------------------------------------------------
grant execute on function public.rpc_driver_request_form(jsonb) to authenticated;
grant execute on function public.rpc_driver_update_form_request(uuid, jsonb) to authenticated;
grant execute on function public.rpc_driver_submit_application(jsonb) to authenticated;

revoke all on function public.fn_assert_vehicle_available(uuid, text, text, text, uuid, uuid)
  from public, anon, authenticated;
