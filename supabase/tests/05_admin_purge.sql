-- ===========================================================================
-- MTOP System — Account purge tests
--
-- Regression for the form-request cleanup inside rpc_admin_purge_account():
-- an account whose own request had been converted into its own application
-- must be purgeable. The `on delete set null` foreign key used to blank
-- converted_application_id while status stayed 'converted', violating
-- form_requests_converted_consistency and failing the whole transaction.
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
    jsonb_build_object('first_name', 'Purge', 'last_name', 'Tester', 'contact_number', '09176667777'),
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
select
  pg_temp.mk_user('purge.admin@test.local', 'administrator') as admin_auth,
  pg_temp.mk_user('purge.driver@test.local', 'driver')       as driver_auth,
  pg_temp.mk_user('purge.staff@test.local', 'staff')         as staff_auth;

create temporary table ids as
select
  (select id from public.profiles where auth_user_id = fx.admin_auth)  as admin,
  (select id from public.profiles where auth_user_id = fx.driver_auth) as driver,
  (select id from public.profiles where auth_user_id = fx.staff_auth)  as staff,
  (select id from public.todas order by code limit 1)                  as toda
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

create or replace function pg_temp.request_payload(p_driver uuid, p_toda uuid)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'application_type', 'new',
    'toda_id', p_toda::text,
    'purpose', 'Franchise application for tricycle PURGE',
    'ctc_number', 'CTC-PURGE',
    'vehicle_make', 'Honda',
    'vehicle_model', 'TMX 155',
    'engine_number', 'ENG-PURGE',
    'chassis_number', 'CHS-PURGE',
    'plate_number', 'PLT PURGE',
    'cr_number', 'CR-PURGE',
    'or_cr_storage_path', p_driver::text || '/form-requests/purge/or-cr.pdf',
    'or_cr_file_name', 'or-cr.pdf',
    'or_cr_mime_type', 'application/pdf',
    'or_cr_file_size_bytes', 250000,
    'signature_typed_name', 'Purge Tester'
  );
$$;

create or replace function pg_temp.app_payload(p_driver uuid, p_toda uuid)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'application_type', 'new',
    'toda_id', p_toda::text,
    'operator_address_line', 'Purok 1, Purge Street',
    'operator_barangay_code', '041016017',
    'vehicle_year', 2019,
    'vehicle_color', 'Blue',
    'seating_capacity', 5,
    'documents', (
      select jsonb_agg(jsonb_build_object(
               'document_type', dt.document_type::text,
               'storage_path', p_driver::text || '/pending/purge-' || dt.document_type::text || '.pdf',
               'file_name', dt.document_type::text || '.pdf',
               'file_size_bytes', 250000,
               'mime_type', 'application/pdf'))
        from unnest(enum_range(null::public.document_type)) as dt(document_type)
       where dt.document_type::text <> 'or_cr'
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- A driver request is converted into the driver's own application
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver_auth from fx));

select lives_ok(
  $$select public.rpc_driver_request_form(
      pg_temp.request_payload((select driver from ids), (select toda from ids)))$$,
  'the driver files a form request'
);

select pg_temp.login((select staff_auth from fx));

select lives_ok(
  $$select public.rpc_staff_issue_form_request(
      (select id from public.form_requests where requested_by = (select driver from ids)))$$,
  'staff issue the request'
);

select pg_temp.login((select driver_auth from fx));

select lives_ok(
  $$select public.rpc_driver_submit_application(
      pg_temp.app_payload((select driver from ids), (select toda from ids)))$$,
  'the driver submits the application and consumes the request'
);

select is(
  (select status::text from public.form_requests
    where requested_by = (select driver from ids)),
  'converted',
  'the request points at the driver''s own application'
);

-- ---------------------------------------------------------------------------
-- The account can now be purged
-- ---------------------------------------------------------------------------
select pg_temp.login((select admin_auth from fx));

select lives_ok(
  $$select public.rpc_admin_purge_account(
      (select driver from ids),
      'Driver requested account deletion')$$,
  'an account with a converted form request can be purged'
);

select is(
  (select count(*)::int from public.profiles where id = (select driver from ids)),
  0,
  'the profile is gone'
);

select is(
  (select count(*)::int from public.form_requests
    where requested_by = (select driver from ids)),
  0,
  'the account''s form requests are gone'
);

select * from finish();
rollback;
