-- ===========================================================================
-- SBTF System — refuse duplicate vehicles on a form request
--
-- A request form carries the vehicle identity (plate, engine, chassis and CR
-- number). Those values identify exactly one tricycle, so a request must not be
-- accepted when the same vehicle is already:
--
--   * covered by an active franchise record (plate/engine/chassis, unless the
--     driver is renewing their own franchise),
--   * claimed by a pending application (plate/engine/chassis), or
--   * claimed by another open request (plate/engine/chassis/CR number).
--
-- CR numbers live only on form requests; applications do not store one, so the
-- application/record branches fall back to the three identity fields above.
--
-- The check lives in `fn_normalize_form_request_payload` so both
-- `rpc_driver_request_form` and `rpc_driver_update_form_request` apply the same
-- rule. Rejected and cancelled requests do not claim a vehicle, so a driver can
-- still correct and resubmit the same row.
-- ===========================================================================

-- --- duplicate vehicle guard for requests ----------------------------------
create or replace function public.fn_assert_form_request_vehicle_available(
  p_actor            uuid,
  p_application_type public.application_type,
  p_plate_number     text,
  p_engine_number    text,
  p_chassis_number   text,
  p_cr_number        text
)
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  -- An active franchise record already covers this vehicle. Renewing the
  -- driver's own franchise is the only allowed match.
  if exists (
    select 1
      from public.franchise_records r
      join public.franchise_applications a on a.id = r.application_id
     where r.archived = false
       and not (p_application_type = 'renewal' and a.applicant_id = p_actor)
       and (
         upper(btrim(a.plate_number))   = upper(btrim(p_plate_number))
         or upper(btrim(a.engine_number))  = upper(btrim(p_engine_number))
         or upper(btrim(a.chassis_number)) = upper(btrim(p_chassis_number))
       )
  ) then
    raise exception 'This vehicle (plate, engine or chassis number) already has an active franchise. Choose "Renewal" if you are renewing it.'
      using errcode = 'P0001';
  end if;

  -- A pending application already claims this vehicle.
  if exists (
    select 1
      from public.franchise_applications a
     where a.status = 'pending'
       and (
         upper(btrim(a.plate_number))   = upper(btrim(p_plate_number))
         or upper(btrim(a.engine_number))  = upper(btrim(p_engine_number))
         or upper(btrim(a.chassis_number)) = upper(btrim(p_chassis_number))
       )
  ) then
    raise exception 'This vehicle (plate, engine or chassis number) is already used by a pending application'
      using errcode = 'P0001';
  end if;

  -- Another open request already claims this vehicle. The caller's own open
  -- request is already refused by the one-open-request rule, so no exclusion is
  -- needed here.
  if exists (
    select 1
      from public.form_requests f
     where f.status in ('requested', 'issued')
       and (
         upper(btrim(f.plate_number))   = upper(btrim(p_plate_number))
         or upper(btrim(f.engine_number))  = upper(btrim(p_engine_number))
         or upper(btrim(f.chassis_number)) = upper(btrim(p_chassis_number))
         or upper(btrim(f.cr_number))      = upper(btrim(p_cr_number))
       )
  ) then
    raise exception 'This vehicle (plate, engine, chassis or CR number) is already used by another open request'
      using errcode = 'P0001';
  end if;
end;
$$;

comment on function public.fn_assert_form_request_vehicle_available(
  uuid, public.application_type, text, text, text, text
) is
  'Refuses a form request when the plate, engine or chassis number is already used by an active franchise or pending application, or when any of those plus the CR number is already used by another open request.';

-- --- normaliser: add the duplicate check ------------------------------------
-- Same body as migration 20261107000400, plus the duplicate guard before the
-- normalised payload is returned. Keeping the check here means create and
-- resubmit cannot drift apart.
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

  perform public.fn_assert_form_request_vehicle_available(
    p_actor,
    v_type::public.application_type,
    v_plate,
    v_engine,
    v_chassis,
    v_cr
  );

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

-- --- privileges -------------------------------------------------------------
revoke all on function public.fn_assert_form_request_vehicle_available(
  uuid, public.application_type, text, text, text, text
) from public, anon, authenticated;
