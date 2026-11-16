-- ===========================================================================
-- MTOP System — 30-day renewal window tests
--
-- A franchise becomes renewable 30 days before expiry and stays renewable
-- after expiry. The rule is enforced by the database, not just the mobile UI.
-- ===========================================================================
begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
create or replace function pg_temp.mk_user(
  p_email text,
  p_role  public.user_role
) returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  )
  values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    p_email, crypt('Test@12345', gen_salt('bf')), now(),
    jsonb_build_object('provider', 'email', 'providers', array['email'], 'role', p_role),
    jsonb_build_object('first_name', 'Renewal', 'last_name', 'Tester', 'contact_number', '09175556666'),
    now(), now(), '', '', '', ''
  );

  update public.profiles
     set role = p_role,
         toda_id = (select id from public.todas order by code limit 1)
   where auth_user_id = v_id;

  return v_id;
end;
$$;

create temporary table fx as
select pg_temp.mk_user('rw.driver@test.local', 'driver') as driver_auth;

create temporary table ids as
select
  (select id from public.profiles where auth_user_id = fx.driver_auth) as driver,
  (select id from public.todas order by code limit 1)                 as toda
from fx;

grant select on fx, ids to anon, authenticated;

create or replace function pg_temp.login(p_auth uuid, p_role text default 'authenticated')
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_auth::text, 'role', p_role, 'aud', 'authenticated')::text,
    true);
  perform set_config('role', p_role, true);
end;
$$;

-- An approved application backs the franchise record (records require one).
create temporary table fx_app (id uuid);

insert into public.franchise_applications (
  application_number, applicant_id, application_type, toda_id,
  operator_first_name, operator_last_name, operator_contact_number,
  operator_address_line, operator_barangay_code,
  vehicle_make, vehicle_model, vehicle_year, vehicle_color,
  plate_number, engine_number, chassis_number,
  status, reviewed_by, reviewed_at
)
select
  'TEST-RW-APP-1', i.driver, 'new', i.toda,
  'Renewal', 'Tester', '09175556666',
  'Purok 1, Renewal Street', '041016017',
  'Honda', 'TMX 155', 2019, 'Blue',
  'RW 001', 'ENG-RW-001', 'CHS-RW-001',
  'approved', i.driver, now()
from ids i;

insert into fx_app
select id from public.franchise_applications where application_number = 'TEST-RW-APP-1';

grant select on fx_app to anon, authenticated;

insert into public.franchise_records (
  application_id, operator_id, toda_id, franchise_number, verification_code,
  issued_at, expires_at
)
select
  a.id, i.driver, i.toda, 'MTOP-RW-0001', 'RENEWWINDOW1',
  now() - interval '11 months', now() + interval '60 days'
from fx_app a, ids i;

create or replace function pg_temp.renewal_request(p_driver uuid, p_toda uuid, p_tag text)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'application_type', 'renewal',
    'toda_id', p_toda::text,
    'purpose', 'Franchise renewal for ' || p_tag,
    'ctc_number', 'CTC-' || p_tag,
    'vehicle_make', 'Honda',
    'vehicle_model', 'TMX 155',
    'engine_number', 'ENG-RW-001',
    'chassis_number', 'CHS-RW-001',
    'plate_number', 'RW 001',
    'cr_number', 'CR-RW-001',
    'or_cr_storage_path', p_driver::text || '/form-requests/' || p_tag || '/or-cr.pdf',
    'or_cr_file_name', 'or-cr.pdf',
    'or_cr_mime_type', 'application/pdf',
    'or_cr_file_size_bytes', 250000,
    'signature_typed_name', 'Renewal Tester'
  );
$$;

-- ---------------------------------------------------------------------------
-- 1. Window helpers
-- ---------------------------------------------------------------------------
select is(
  public.fn_renewal_window_days(),
  30,
  'the renewal window is fixed at 30 days'
);

select is(
  public.fn_renewal_opens_at('2026-12-31T00:00:00+00'::timestamptz),
  '2026-12-01T00:00:00+00'::timestamptz,
  'the window opens exactly 30 days before expiry'
);

select is(
  public.fn_renewal_is_open(now() + interval '31 days'),
  false,
  'a franchise expiring in 31 days is not renewable yet'
);

select ok(
  public.fn_renewal_is_open(now() + interval '29 days'),
  'a franchise expiring in 29 days is renewable'
);

select ok(
  public.fn_renewal_is_open(now() - interval '1 day'),
  'an expired franchise stays renewable'
);

-- ---------------------------------------------------------------------------
-- 2. Server enforcement on the request RPC
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver_auth from fx));

select throws_ok(
  $$select public.rpc_driver_request_form(
      pg_temp.renewal_request((select driver from ids), (select toda from ids), 'RW1'))$$,
  'P0001', null,
  'a renewal request more than 30 days before expiry is refused'
);

select set_config('role', 'postgres', true);

update public.franchise_records
   set expires_at = now() + interval '20 days'
 where franchise_number = 'MTOP-RW-0001';

select set_config('role', 'authenticated', true);

select lives_ok(
  $$select public.rpc_driver_request_form(
      pg_temp.renewal_request((select driver from ids), (select toda from ids), 'RW2'))$$,
  'a renewal request inside the 30-day window is accepted'
);

select * from finish();
rollback;
