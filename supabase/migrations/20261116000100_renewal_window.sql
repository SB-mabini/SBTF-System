-- ===========================================================================
-- MTOP System — 30-day renewal window
--
-- A franchise may be renewed from 30 days before it expires, and the window
-- stays open after expiry so a lapsed franchise can still be renewed. The rule
-- is enforced in the database (not just the mobile UI) by the driver RPCs and
-- is reflected in the wording of the 90/60-day renewal reminders.
--
-- This migration redefines the latest versions of:
--   * public.rpc_driver_request_form        (20261107000400)
--   * public.rpc_driver_submit_application  (20261107000400)
--   * public.rpc_generate_renewal_reminders (20260101090700)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Window helpers (single source of truth for the 30-day rule)
-- ---------------------------------------------------------------------------
create or replace function public.fn_renewal_window_days()
returns integer
language sql
immutable
as $$
  select 30;
$$;

comment on function public.fn_renewal_window_days() is
  'Number of days before expiry at which a franchise becomes renewable.';

create or replace function public.fn_renewal_opens_at(p_expires_at timestamptz)
returns timestamptz
language sql
immutable
as $$
  select p_expires_at - make_interval(days => public.fn_renewal_window_days());
$$;

comment on function public.fn_renewal_opens_at(timestamptz) is
  'The instant a franchise record enters its renewal window.';

create or replace function public.fn_renewal_is_open(p_expires_at timestamptz)
returns boolean
language sql
stable
as $$
  select now() >= public.fn_renewal_opens_at(p_expires_at);
$$;

comment on function public.fn_renewal_is_open(timestamptz) is
  'True once a franchise is within 30 days of expiry or already expired.';

-- ===========================================================================
-- DRIVER: request a form (renewals only open 30 days before expiry)
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
  v_opens  timestamptz;
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

-- ===========================================================================
-- DRIVER: submit a new or renewal application (request-gated)
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
  'Driver/operator submits a new or renewal franchise application. Requires a staff-approved form request of the same type; renewals are accepted from 30 days before expiry onwards. The request supplies vehicle identity and OR/CR, and is consumed atomically.';

-- ===========================================================================
-- SYSTEM: renewal reminders (scheduled server-side; never mutates records)
--
-- 90/60-day reminders tell the operator to prepare documents and state when
-- the renewal window opens; the 30-day reminder invites immediate filing.
-- ===========================================================================
create or replace function public.rpc_generate_renewal_reminders(
  p_days integer[] default array[90, 60, 30]
)
returns table (records_evaluated integer, reminders_created integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_window    integer;
  v_rec       record;
  v_evaluated integer := 0;
  v_created   integer := 0;
  v_inserted  boolean;
  v_message   text;
begin
  foreach v_window in array p_days
  loop
    for v_rec in
      select fr.id,
             fr.operator_id,
             fr.franchise_number,
             fr.expires_at,
             p.renewal_reminders
        from public.franchise_records fr
        join public.profiles p on p.id = fr.operator_id
       where fr.archived = false
         and fr.expires_at > now()
         and fr.expires_at <= now() + make_interval(days => v_window)
         -- A renewal already in progress does not need another reminder
         and not exists (
               select 1 from public.franchise_applications a
                where a.renewal_of_record_id = fr.id and a.status = 'pending'
             )
    loop
      v_evaluated := v_evaluated + 1;

      insert into public.renewal_reminders_sent (record_id, window_days)
      values (v_rec.id, v_window)
      on conflict (record_id, window_days) do nothing;
      v_inserted := found;

      if v_inserted then
        if coalesce(v_rec.renewal_reminders, true) then
          if v_window > public.fn_renewal_window_days() then
            v_message :=
              'Franchise ' || v_rec.franchise_number || ' expires on ' ||
              to_char(v_rec.expires_at, 'FMMonth FMDD, YYYY') ||
              ' (' || greatest(ceil(extract(epoch from (v_rec.expires_at - now())) / 86400), 0)::integer ||
              ' days remaining). Prepare your documents — renewal opens on ' ||
              to_char(public.fn_renewal_opens_at(v_rec.expires_at), 'FMMonth FMDD, YYYY') || '.';
          else
            v_message :=
              'Franchise ' || v_rec.franchise_number || ' expires on ' ||
              to_char(v_rec.expires_at, 'FMMonth FMDD, YYYY') ||
              ' (' || greatest(ceil(extract(epoch from (v_rec.expires_at - now())) / 86400), 0)::integer ||
              ' days remaining). Your renewal window is open — file the renewal application in the mobile app.';
          end if;

          perform public.fn_notify(
            v_rec.operator_id,
            'Franchise renewal reminder',
            v_message,
            'renewal_reminder',
            'franchise_record',
            v_rec.id
          );

          perform public.fn_log_activity(
            null, 'renewal_reminder_sent', 'franchise_record', v_rec.id,
            jsonb_build_object('window_days', v_window, 'franchise_number', v_rec.franchise_number)
          );

          v_created := v_created + 1;
        end if;
      end if;
    end loop;
  end loop;

  return query select v_evaluated, v_created;
end;
$$;

comment on function public.rpc_generate_renewal_reminders(integer[]) is
  'Creates renewal reminder notifications for franchises entering the 90/60/30-day windows. Early reminders say when the 30-day renewal window opens; the final one invites filing. Idempotent per record and window; never modifies franchise records.';

-- --- privileges -------------------------------------------------------------
revoke all on function public.fn_renewal_window_days() from public, anon, authenticated;
revoke all on function public.fn_renewal_opens_at(timestamptz) from public, anon, authenticated;
revoke all on function public.fn_renewal_is_open(timestamptz) from public, anon, authenticated;
