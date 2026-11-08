-- ===========================================================================
-- SBTF System — Official application form + Authority to Operate
-- Adds the fields the printed application form (Image 1) needs, copies the
-- request-form CTC/signature onto the application, records payment details for
-- the Authority (Image 2), and moves new franchises to a 2-year validity.
-- ===========================================================================

-- --- form requests: CTC issue place/date ------------------------------------
alter table public.form_requests
  add column if not exists ctc_issued_at text default 'Mabini, Batangas',
  add column if not exists ctc_issued_on date default current_date;

update public.form_requests
   set ctc_issued_at = coalesce(nullif(btrim(ctc_issued_at), ''), 'Mabini, Batangas'),
       ctc_issued_on = coalesce(ctc_issued_on, requested_at::date)
 where ctc_issued_at is null or ctc_issued_on is null;

-- --- applications: official form fields ------------------------------------
alter table public.franchise_applications
  add column if not exists operator_citizenship text default 'Filipino',
  add column if not exists applied_route text,
  add column if not exists registered_owner text,
  add column if not exists ownership_type text,
  add column if not exists ctc_number text,
  add column if not exists ctc_issued_at text,
  add column if not exists ctc_issued_on date,
  add column if not exists applicant_signature_storage_path text,
  add column if not exists applicant_signature_typed_name text;

alter table public.franchise_applications drop constraint if exists franchise_applications_ownership_type_valid;
alter table public.franchise_applications drop constraint if exists franchise_applications_ownership_type_check;

update public.franchise_applications
   set ownership_type = 'single_proprietorship'
 where ownership_type = 'sole_proprietorship';

alter table public.franchise_applications add constraint franchise_applications_ownership_type_check
  check (ownership_type is null or ownership_type in
         ('single_proprietorship', 'cooperative', 'corporation', 'not_applicable'));

alter table public.franchise_applications drop constraint if exists franchise_applications_route_length;
alter table public.franchise_applications add constraint franchise_applications_route_length
  check (applied_route is null or length(btrim(applied_route)) between 3 and 120);

alter table public.franchise_applications drop constraint if exists franchise_applications_registered_owner_required;
alter table public.franchise_applications add constraint franchise_applications_registered_owner_required
  check (ownership_type is null
         or ownership_type not in ('cooperative', 'corporation')
         or (registered_owner is not null and length(btrim(registered_owner)) > 0));

comment on column public.franchise_applications.applied_route is
  'Free-text route / authorized service area requested by the applicant, e.g. "Mainaga - Poblacion".';
comment on column public.franchise_applications.applicant_signature_storage_path is
  'Signature drawn on the approved form request and reused on the application form and Authority.';
comment on column public.franchise_applications.ctc_number is
  'Community Tax Certificate number copied from the approved form request.';

-- Backfill existing applications from their TODA / approved request.
update public.franchise_applications a
   set operator_citizenship = coalesce(a.operator_citizenship, 'Filipino'),
       applied_route = coalesce(a.applied_route, t.name),
       ownership_type = coalesce(a.ownership_type, 'not_applicable')
  from public.todas t
 where t.id = a.toda_id
   and (a.operator_citizenship is null or a.applied_route is null or a.ownership_type is null);

update public.franchise_applications a
   set ctc_number = coalesce(a.ctc_number, f.ctc_number),
       ctc_issued_at = coalesce(a.ctc_issued_at, f.ctc_issued_at),
       ctc_issued_on = coalesce(a.ctc_issued_on, f.ctc_issued_on),
       applicant_signature_storage_path = coalesce(a.applicant_signature_storage_path, f.signature_storage_path),
       applicant_signature_typed_name = coalesce(a.applicant_signature_typed_name, f.signature_typed_name)
  from public.form_requests f
 where f.converted_application_id = a.id
   and (a.ctc_number is null or a.applicant_signature_storage_path is null);

-- --- records: payment details printed on the Authority ----------------------
alter table public.franchise_records
  add column if not exists official_receipt_number text,
  add column if not exists official_receipt_date date,
  add column if not exists amount_paid numeric(10, 2);

alter table public.franchise_records drop constraint if exists franchise_records_amount_paid_check;
alter table public.franchise_records add constraint franchise_records_amount_paid_check
  check (amount_paid is null or amount_paid >= 0);

comment on column public.franchise_records.official_receipt_number is
  'O.R. number entered by staff at release; printed under "PAID UNDER O.R. NO." on the Authority.';

-- --- driver: fill the official form fields right after submitting ----------
create or replace function public.rpc_driver_set_application_details(
  p_application_id uuid,
  p_payload        jsonb
)
returns public.franchise_applications
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor     uuid := public.current_profile_id();
  v_app       public.franchise_applications;
  v_form      public.form_requests;
  v_route     text;
  v_citizen   text;
  v_owner     text;
  v_ownership text;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_app
    from public.franchise_applications
   where id = p_application_id
   for update;

  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.applicant_id <> v_actor then
    raise exception 'You may only update your own application' using errcode = '42501';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application is no longer editable' using errcode = 'P0001';
  end if;

  v_route := public.fn_required_text(p_payload, 'applied_route', 3, 120);
  v_citizen := coalesce(public.fn_optional_text(p_payload, 'operator_citizenship', 40), 'Filipino');
  v_ownership := lower(coalesce(
    nullif(btrim(coalesce(p_payload ->> 'ownership_type', '')), ''),
    'not_applicable'
  ));

  if v_ownership not in ('single_proprietorship', 'cooperative', 'corporation', 'not_applicable') then
    raise exception 'Unknown type of ownership' using errcode = 'P0001';
  end if;

  v_owner := public.fn_optional_text(p_payload, 'registered_owner', 160);
  if v_ownership in ('cooperative', 'corporation') and v_owner is null then
    raise exception 'Registered owner is required for a cooperative or corporation'
      using errcode = 'P0001';
  end if;

  select * into v_form
    from public.form_requests
   where converted_application_id = v_app.id
   order by issued_at desc nulls last
   limit 1;

  update public.franchise_applications
     set applied_route = v_route,
         operator_citizenship = v_citizen,
         registered_owner = v_owner,
         ownership_type = v_ownership,
         ctc_number = coalesce(v_form.ctc_number, ctc_number),
         ctc_issued_at = coalesce(v_form.ctc_issued_at, ctc_issued_at),
         ctc_issued_on = coalesce(v_form.ctc_issued_on, ctc_issued_on),
         applicant_signature_storage_path = coalesce(v_form.signature_storage_path, applicant_signature_storage_path),
         applicant_signature_typed_name = coalesce(v_form.signature_typed_name, applicant_signature_typed_name)
   where id = v_app.id
  returning * into v_app;

  return v_app;
end;
$$;

comment on function public.rpc_driver_set_application_details(uuid, jsonb) is
  'Driver fills the official application-form fields (route, citizenship, registered owner, ownership) and the CTC/signature are copied from the approved request.';

-- --- staff: record O.R. details for the Authority ---------------------------
create or replace function public.rpc_staff_record_franchise_payment(
  p_record_id uuid,
  p_or_number text,
  p_or_date   date,
  p_amount    numeric
)
returns public.franchise_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_record public.franchise_records;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  if p_amount is not null and p_amount < 0 then
    raise exception 'Amount paid cannot be negative' using errcode = 'P0001';
  end if;

  update public.franchise_records
     set official_receipt_number = nullif(btrim(coalesce(p_or_number, '')), ''),
         official_receipt_date = p_or_date,
         amount_paid = p_amount
   where id = p_record_id
  returning * into v_record;

  if not found then
    raise exception 'Franchise record not found' using errcode = 'P0002';
  end if;

  return v_record;
end;
$$;

comment on function public.rpc_staff_record_franchise_payment(uuid, text, date, numeric) is
  'Staff records the O.R. number/date/amount printed on the Authority to Operate.';

-- --- settings: official board, signatory, fares and 2-year validity ---------
insert into public.system_settings (key, value, data_type, category, label, description, is_public)
values
  ('certificate_board_name', '"MABINI TRICYCLE FRANCHISING AND REGULATORY BOARD"'::jsonb, 'string', 'certificate',
   'Board name', 'Letterhead name printed on the Authority to Operate.', true),
  ('certificate_signatory_name', '"HON. PABLO M. VILLANUEVA, JR"'::jsonb, 'string', 'certificate',
   'Signatory name', 'Name printed above the signatory line on the Authority.', true),
  ('certificate_signatory_position', '"Vice Chairman, Tricycle Franchising and Regulatory Board"'::jsonb, 'string', 'certificate',
   'Signatory position', 'Position printed below the signatory name.', true),
  ('certificate_fare_first_km', '"8.00"'::jsonb, 'string', 'certificate',
   'Fare — first km', 'Fare for the first kilometre printed in the conditions.', true),
  ('certificate_fare_succeeding_km', '"1.00"'::jsonb, 'string', 'certificate',
   'Fare — succeeding km', 'Fare for each succeeding kilometre.', true),
  ('certificate_supervision_fee', '"120.00"'::jsonb, 'string', 'certificate',
   'Supervision fee', 'Annual supervision fee printed in the conditions.', true),
  ('certificate_supervision_due', '"September 30"'::jsonb, 'string', 'certificate',
   'Supervision fee due date', 'Date by which the supervision fee is paid.', true),
  ('franchise_validity_months', '24'::jsonb, 'number', 'franchise',
   'Franchise validity (months)', 'Validity applied to newly issued franchises (24 months = 2 years).', true)
on conflict (key) do update
  set value = excluded.value,
      label = excluded.label,
      description = excluded.description,
      category = excluded.category,
      updated_at = now();

-- --- grants -----------------------------------------------------------------
grant execute on function public.rpc_driver_set_application_details(uuid, jsonb) to authenticated;
grant execute on function public.rpc_staff_record_franchise_payment(uuid, text, date, numeric) to authenticated;
