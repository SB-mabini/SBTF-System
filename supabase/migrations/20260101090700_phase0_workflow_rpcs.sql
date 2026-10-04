-- ===========================================================================
-- SBTF System — Phase 0.8
-- Business workflow RPCs (SECURITY DEFINER).
--
-- These functions are the ONLY way applications move through the workflow.
-- They validate every business rule server-side, so a tampered client cannot
-- approve its own application, skip document verification, or escalate a role.
-- ===========================================================================

-- --- small JSON payload helpers ---------------------------------------------
create or replace function public.fn_required_text(
  p_payload jsonb, p_key text, p_min integer default 1, p_max integer default 200
)
returns text
language plpgsql
immutable
as $$
declare
  v_value text;
begin
  if p_payload is null or not (p_payload ? p_key) or jsonb_typeof(p_payload -> p_key) <> 'string' then
    raise exception 'Missing required field: %', p_key using errcode = 'P0001';
  end if;

  v_value := btrim(p_payload ->> p_key);

  if length(v_value) < p_min or length(v_value) > p_max then
    raise exception 'Field "%" must be between % and % characters', p_key, p_min, p_max
      using errcode = 'P0001';
  end if;

  return v_value;
end;
$$;

create or replace function public.fn_optional_text(
  p_payload jsonb, p_key text, p_max integer default 200
)
returns text
language plpgsql
immutable
as $$
declare
  v_value text;
begin
  if p_payload is null or not (p_payload ? p_key) or jsonb_typeof(p_payload -> p_key) = 'null' then
    return null;
  end if;

  v_value := nullif(btrim(p_payload ->> p_key), '');
  if v_value is null then
    return null;
  end if;

  if length(v_value) > p_max then
    raise exception 'Field "%" must not exceed % characters', p_key, p_max using errcode = 'P0001';
  end if;

  return v_value;
end;
$$;

-- ===========================================================================
-- DRIVER: submit a new or renewal franchise application
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
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_role := public.current_user_role();
  if v_role <> 'driver' then
    raise exception 'Only driver/operator accounts may submit franchise applications'
      using errcode = '42501';
  end if;

  -- Application type
  if (p_payload ->> 'application_type') not in ('new', 'renewal') then
    raise exception 'application_type must be either "new" or "renewal"' using errcode = 'P0001';
  end if;
  v_type := (p_payload ->> 'application_type')::public.application_type;

  -- TODA
  begin
    v_toda_id := (p_payload ->> 'toda_id')::uuid;
  exception when others then
    raise exception 'A valid TODA must be selected' using errcode = 'P0001';
  end;

  if not exists (select 1 from public.todas t where t.id = v_toda_id and t.is_active) then
    raise exception 'The selected TODA is not accredited or is inactive' using errcode = 'P0001';
  end if;

  -- Barangay of the operator address
  v_barangay := public.fn_optional_text(p_payload, 'operator_barangay_code', 20);
  if v_barangay is not null and not exists (select 1 from public.barangays b where b.code = v_barangay) then
    raise exception 'Unknown barangay code' using errcode = 'P0001';
  end if;

  -- Vehicle year / capacity with friendly validation
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

  -- Renewal specific rules
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

  -- Documents: exactly the four required requirements, referencing this user's folder
  v_documents := p_payload -> 'documents';
  if v_documents is null or jsonb_typeof(v_documents) <> 'array' then
    raise exception 'documents must be an array of uploaded documentary requirements'
      using errcode = 'P0001';
  end if;

  v_expected := (select count(*) from unnest(enum_range(null::public.document_type)));
  v_provided := (select count(distinct (d ->> 'document_type')::public.document_type)
                   from jsonb_array_elements(v_documents) d);
  if v_provided <> v_expected then
    raise exception 'All four documentary requirements are required (expected %, received %)',
      v_expected, coalesce(v_provided, 0) using errcode = 'P0001';
  end if;

  select string_agg(dt::text, ', ') into v_missing
    from unnest(enum_range(null::public.document_type)) as dt
   where not exists (
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

  -- Create the application
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
    public.fn_required_text(p_payload, 'operator_first_name', 1, 80),
    public.fn_optional_text(p_payload, 'operator_middle_name', 80),
    public.fn_required_text(p_payload, 'operator_last_name', 1, 80),
    public.fn_required_text(p_payload, 'operator_contact_number', 7, 20),
    public.fn_required_text(p_payload, 'operator_address_line', 5, 200),
    v_barangay,
    public.fn_optional_text(p_payload, 'operator_email', 160),
    public.fn_required_text(p_payload, 'vehicle_make', 1, 60),
    public.fn_required_text(p_payload, 'vehicle_model', 1, 60),
    v_vehicle_year,
    public.fn_required_text(p_payload, 'vehicle_color', 2, 40),
    upper(public.fn_required_text(p_payload, 'plate_number', 3, 20)),
    public.fn_required_text(p_payload, 'engine_number', 3, 40),
    public.fn_required_text(p_payload, 'chassis_number', 3, 40),
    v_capacity,
    public.fn_optional_text(p_payload, 'mtop_number', 60),
    public.fn_optional_text(p_payload, 'body_number', 60),
    case when v_type = 'renewal' then v_record.id else null end,
    public.fn_optional_text(p_payload, 'remarks', 1000),
    now()
  )
  returning * into v_app;

  -- Attach documents (verification starts as pending)
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

  -- Keep the operator profile aligned with the declared TODA.
  update public.profiles
     set toda_id = coalesce(toda_id, v_toda_id)
   where id = v_actor;

  return v_app;
end;
$$;

comment on function public.rpc_driver_submit_application(jsonb) is
  'Driver/operator submits a new or renewal franchise application together with the four required documents. All validation is server-side.';

-- ===========================================================================
-- STAFF: start reviewing an application
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
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  if v_app.review_started_at is null then
    update public.franchise_applications
       set review_started_at = now(), review_started_by = v_actor
     where id = v_app.id
    returning * into v_app;

    perform public.fn_add_application_event(v_app.id, 'review_started', v_actor, 'Review started');
    perform public.fn_log_activity(v_actor, 'review_started', 'franchise_application', v_app.id,
      jsonb_build_object('application_number', v_app.application_number));
    perform public.fn_notify(v_app.applicant_id, 'Application under review',
      'Your application ' || v_app.application_number || ' is now being reviewed by the franchising office.',
      'application_under_review', 'franchise_application', v_app.id);
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
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
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
-- STAFF: approve an application → issue the franchise record
-- ===========================================================================
create or replace function public.rpc_staff_approve_application(p_application_id uuid)
returns public.franchise_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor      uuid := public.current_profile_id();
  v_app        public.franchise_applications;
  v_record     public.franchise_records;
  v_outstanding integer;
  v_validity   integer;
  v_prefix     text;
  v_year       integer := extract(year from now())::int;
  v_seq        integer;
  v_number     text;
  v_code       text;
  v_expires    timestamptz;
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  -- Every required document must be verified first: approval cannot skip
  -- document verification, and no automated approval path exists.
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

  select coalesce((value #>> '{}')::integer, 12) into v_validity
    from public.system_settings where key = 'franchise_validity_months';
  v_validity := coalesce(v_validity, 12);

  select coalesce(value #>> '{}', 'MAB-TR') into v_prefix
    from public.system_settings where key = 'franchise_number_prefix';
  v_prefix := coalesce(nullif(btrim(v_prefix), ''), 'MAB-TR');

  v_seq := public.fn_next_sequence('franchise', v_year);
  v_number := v_prefix || '-' || v_year || '-' || lpad(v_seq::text, 6, '0');
  v_code := public.fn_generate_verification_code();
  v_expires := now() + make_interval(months => v_validity);

  insert into public.franchise_records (
    application_id, operator_id, toda_id, franchise_number, verification_code, issued_at, expires_at
  )
  values (
    v_app.id, v_app.applicant_id, v_app.toda_id, v_number, v_code, now(), v_expires
  )
  returning * into v_record;

  -- Link the renewed predecessor record for traceability (the predecessor is
  -- never modified beyond this forward link, and never auto-expired/auto-renewed).
  if v_app.renewal_of_record_id is not null then
    update public.franchise_records
       set renewed_by_record_id = v_record.id
     where id = v_app.renewal_of_record_id
       and renewed_by_record_id is null;
  end if;

  update public.franchise_applications
     set status = 'approved',
         reviewed_by = v_actor,
         reviewed_at = now(),
         rejection_reason = null
   where id = v_app.id;

  return v_record;
end;
$$;

comment on function public.rpc_staff_approve_application(uuid) is
  'Approves a fully verified application and issues a franchise record. Requires staff/admin; never automatic.';

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
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
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
         rejection_reason = v_reason,
         reviewed_by = v_actor,
         reviewed_at = now()
   where id = v_app.id
  returning * into v_app;

  return v_app;
end;
$$;

-- ===========================================================================
-- STAFF: attach the generated certificate and archive records
-- ===========================================================================
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
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  select * into v_record from public.franchise_records where id = p_record_id for update;
  if not found then
    raise exception 'Franchise record not found' using errcode = 'P0002';
  end if;

  -- Certificates live in the certificate bucket inside the operator's folder,
  -- which is exactly what the storage read policy checks (folder 1 = profile id).
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
  v_actor  uuid := public.current_profile_id();
  v_record public.franchise_records;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  if p_archived and (v_reason is null or length(v_reason) < 5) then
    raise exception 'An archive reason of at least 5 characters is required' using errcode = 'P0001';
  end if;

  update public.franchise_records
     set archived = p_archived,
         archived_at = case when p_archived then now() else null end,
         archived_by = case when p_archived then v_actor else null end,
         archive_reason = case when p_archived then v_reason else null end
   where id = p_record_id
  returning * into v_record;

  if not found then
    raise exception 'Franchise record not found' using errcode = 'P0002';
  end if;

  return v_record;
end;
$$;

-- ===========================================================================
-- ADMINISTRATOR: role and account-status management
-- ===========================================================================
create or replace function public.rpc_admin_set_user_role(
  p_profile_id uuid,
  p_role       public.user_role
)
returns public.profiles
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor   uuid := public.current_profile_id();
  v_target  public.profiles;
  v_admins  integer;
begin
  if not public.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if p_role is null or p_role not in ('administrator', 'staff', 'driver') then
    raise exception 'Invalid role. Allowed roles are administrator, staff and driver'
      using errcode = 'P0001';
  end if;

  if p_profile_id = v_actor then
    raise exception 'Administrators cannot change their own role' using errcode = '42501';
  end if;

  select * into v_target from public.profiles where id = p_profile_id for update;
  if not found then
    raise exception 'User not found' using errcode = 'P0002';
  end if;

  -- Never allow the system to be left without an active administrator.
  if v_target.role = 'administrator' and p_role <> 'administrator' and v_target.account_status = 'active' then
    select count(*) into v_admins
      from public.profiles
     where role = 'administrator' and account_status = 'active';

    if v_admins <= 1 then
      raise exception 'The last active administrator cannot be demoted' using errcode = 'P0001';
    end if;
  end if;

  update public.profiles set role = p_role where id = p_profile_id
  returning * into v_target;

  return v_target;
end;
$$;

create or replace function public.rpc_admin_set_account_status(
  p_profile_id uuid,
  p_status     public.account_status,
  p_reason     text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor  uuid := public.current_profile_id();
  v_target public.profiles;
  v_admins integer;
begin
  if not public.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if p_status is null then
    raise exception 'A target account status is required' using errcode = 'P0001';
  end if;

  if p_profile_id = v_actor then
    raise exception 'Administrators cannot change the status of their own account'
      using errcode = '42501';
  end if;

  select * into v_target from public.profiles where id = p_profile_id for update;
  if not found then
    raise exception 'User not found' using errcode = 'P0002';
  end if;

  if v_target.role = 'administrator' and p_status <> 'active' then
    select count(*) into v_admins
      from public.profiles
     where role = 'administrator' and account_status = 'active';

    if v_admins <= 1 then
      raise exception 'The last active administrator cannot be deactivated' using errcode = 'P0001';
    end if;
  end if;

  update public.profiles
     set account_status = p_status,
         status_reason = case when p_status = 'active' then null else nullif(btrim(coalesce(p_reason, '')), '') end
   where id = p_profile_id
  returning * into v_target;

  return v_target;
end;
$$;

-- ===========================================================================
-- PUBLIC: certificate verification (QR code landing page / mobile scanner)
-- ===========================================================================
create or replace function public.rpc_verify_certificate(p_code text)
returns table (
  verification_status  public.certificate_verification_status,
  franchise_number     text,
  operator_display_name text,
  toda_name            text,
  issued_at            timestamptz,
  expires_at           timestamptz,
  verified_at          timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_code   text;
  v_status public.certificate_verification_status;
  v_number text;
  v_name   text;
  v_toda   text;
  v_issued timestamptz;
  v_expires timestamptz;
begin
  -- Accept codes typed with separators or lowercase.
  v_code := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));

  if length(v_code) = 12 then
    select
      case
        when fr.archived then 'archived'::public.certificate_verification_status
        when fr.expires_at < now() then 'expired'::public.certificate_verification_status
        else 'valid'::public.certificate_verification_status
      end,
      fr.franchise_number,
      upper(left(p.first_name, 1)) || repeat('*', greatest(length(p.first_name) - 1, 2)) || ' ' ||
        upper(left(p.last_name, 1)) || repeat('*', greatest(length(p.last_name) - 1, 2)),
      t.name,
      fr.issued_at,
      fr.expires_at
    into v_status, v_number, v_name, v_toda, v_issued, v_expires
    from public.franchise_records fr
    join public.profiles p on p.id = fr.operator_id
    join public.todas t on t.id = fr.toda_id
    where fr.verification_code = v_code;
  end if;

  if v_number is null then
    -- Record unsuccessful verification attempts as a security-relevant event
    -- without storing the attempted code itself (hash only).
    perform public.fn_log_activity(
      public.current_profile_id(),
      'security_event',
      'franchise_record',
      null,
      jsonb_build_object(
        'event', 'certificate_verification_failed',
        'code_hash', encode(digest(v_code, 'sha256'), 'hex')
      )
    );

    return query
      select 'not_found'::public.certificate_verification_status,
             null::text, null::text, null::text, null::timestamptz, null::timestamptz, now();
    return;
  end if;

  return query select v_status, v_number, v_name, v_toda, v_issued, v_expires, now();
end;
$$;

comment on function public.rpc_verify_certificate(text) is
  'Resolves a certificate verification code and returns only non-sensitive fields with a masked operator name. Safe for anonymous use by the QR scanner.';

-- ===========================================================================
-- SYSTEM: renewal reminders (scheduled server-side; never mutates records)
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
          perform public.fn_notify(
            v_rec.operator_id,
            'Franchise renewal reminder',
            'Franchise ' || v_rec.franchise_number || ' expires on ' ||
              to_char(v_rec.expires_at, 'FMMonth FMDD, YYYY') ||
              ' (' || greatest(ceil(extract(epoch from (v_rec.expires_at - now())) / 86400), 0)::integer ||
              ' days remaining). You may file a renewal application in the mobile app.',
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
  'Creates renewal reminder notifications for franchises entering the 90/60/30-day windows. Idempotent per record and window; never modifies franchise records.';
