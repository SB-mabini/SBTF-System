-- ===========================================================================
-- SBTF System — security / Row Level Security test suite (pgTAP)
--
-- Run with:
--     supabase db reset                    -- applies migrations + seed.sql
--     supabase test db supabase/tests      -- executes this suite
--
-- Every assertion checks a DATABASE-level guarantee. The tests sign in as
-- different roles by switching the PostgreSQL role and the JWT claims exactly
-- the way PostgREST does, so the code path exercised is the same one a browser
-- or mobile request would take.
-- ===========================================================================

begin;

create extension if not exists pgtap with schema extensions;

select plan(45);

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
    jsonb_build_object('first_name', 'Test', 'last_name', 'User', 'contact_number', '09170000000'),
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
  pg_temp.mk_user('rls.driver1@test.local', 'driver')       as driver1_auth,
  pg_temp.mk_user('rls.driver2@test.local', 'driver')       as driver2_auth,
  pg_temp.mk_user('rls.staff@test.local', 'staff')          as staff_auth,
  pg_temp.mk_user('rls.admin@test.local', 'administrator')  as admin_auth;

create temporary table ids as
select
  (select id from public.profiles where auth_user_id = fx.driver1_auth) as driver1,
  (select id from public.profiles where auth_user_id = fx.driver2_auth) as driver2,
  (select id from public.profiles where auth_user_id = fx.staff_auth)   as staff,
  (select id from public.profiles where auth_user_id = fx.admin_auth)   as admin,
  (select id from public.todas order by code limit 1)                   as toda
from fx;

-- A pending application owned by driver 1, with its four documentary
-- requirements, created outside RLS the way the submission RPC does it.
create or replace function pg_temp.mk_fixture_application(p_driver uuid, p_toda uuid)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  insert into public.franchise_applications (
    application_number, applicant_id, application_type, toda_id,
    operator_first_name, operator_last_name, operator_contact_number,
    operator_address_line, vehicle_make, vehicle_model, vehicle_year, vehicle_color,
    plate_number, engine_number, chassis_number
  ) values (
    'TEST-APP-000001', p_driver, 'new', p_toda,
    'Rls', 'Driver', '09170000000', 'Purok 1, Test', 'Honda', 'TMX 155', 2015, 'Blue',
    'TST-001', 'ENG-0001', 'CHS-0001'
  )
  returning id into v_id;

  return v_id;
end;
$$;

create temporary table fx_app as
select pg_temp.mk_fixture_application((select driver1 from ids), (select toda from ids)) as id;

insert into public.franchise_documents (application_id, document_type, storage_path, file_name, mime_type)
select a.id, dt.document_type,
       i.driver1::text || '/' || a.id::text || '/' || dt.document_type::text || '.pdf',
       dt.document_type::text || '.pdf', 'application/pdf'
  from fx_app a, ids i, unnest(enum_range(null::public.document_type)) as dt(document_type);

-- Client roles must be able to read the fixture tables during impersonation.
grant select on fx, ids, fx_app to anon, authenticated;

-- An audit row, so the append-only triggers have something to protect.
insert into public.activity_logs (user_id, action, target_type, metadata)
select driver1, 'login', 'system', '{"fixture": true}'::jsonb from ids;

-- Helper: impersonate a user exactly as PostgREST does.
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

-- ---------------------------------------------------------------------------
-- 1. Row Level Security is switched on everywhere
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0,
  'every table in the public schema has Row Level Security enabled'
);

select is(
  (select count(*)::int from pg_policies where schemaname = 'public'),
  28,
  'the expected number of RLS policies exists'
);

-- ---------------------------------------------------------------------------
-- 2. Driver authorisation
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver1_auth from fx));

select is(
  (select count(*)::int from public.profiles),
  1,
  'a driver sees only their own profile row'
);

select is(
  (select count(*)::int from public.profiles where id = (select driver2 from ids)),
  0,
  'a driver cannot read another driver profile'
);

select is(
  (select count(*)::int from public.franchise_applications),
  1,
  'a driver sees exactly their own application'
);

select throws_ok(
  $$insert into public.franchise_applications (
      application_number, applicant_id, application_type, toda_id,
      operator_first_name, operator_last_name, operator_contact_number,
      operator_address_line, vehicle_make, vehicle_model, vehicle_year, vehicle_color,
      plate_number, engine_number, chassis_number)
    values ('TEST-BYPASS-1', (select driver1 from ids), 'new', (select toda from ids),
      'A', 'B', '09170000000', 'Purok 1', 'Honda', 'TMX', 2015, 'Blue',
      'XXX-1', 'E1', 'C1')$$,
  '42501',
  null,
  'clients cannot insert applications directly; submission must go through the RPC'
);

select throws_ok(
  $$select public.rpc_staff_approve_application((select id from fx_app))$$,
  '42501',
  null,
  'a driver cannot approve an application through the staff RPC'
);

select throws_ok(
  $$update public.profiles set role = 'administrator' where id = (select driver1 from ids)$$,
  '42501',
  null,
  'a driver cannot modify their own role (the privilege is not granted)'
);

select throws_ok(
  $$update public.profiles set account_status = 'active' where id = (select driver1 from ids)$$,
  '42501',
  null,
  'a driver cannot modify account status'
);

select lives_ok(
  $$update public.profiles set contact_number = '09179999999' where id = (select driver1 from ids)$$,
  'a driver may still edit their own descriptive profile fields'
);

select throws_ok(
  $$insert into public.franchise_records (application_id, operator_id, toda_id, franchise_number,
      verification_code, issued_at, expires_at)
    values ((select id from fx_app), (select driver1 from ids), (select toda from ids),
      'FAKE-1', 'FAKE', now(), now() + interval '1 year')$$,
  '42501',
  null,
  'a driver cannot insert a franchise record directly'
);

select throws_ok(
  $$update public.franchise_applications set status = 'approved' where applicant_id = (select driver1 from ids)$$,
  '42501',
  null,
  'a driver cannot change the status of their own application'
);

select throws_ok(
  $$select public.rpc_analytics_overview()$$,
  '42501',
  null,
  'a driver cannot read franchising analytics'
);

select throws_ok(
  $$update public.activity_logs set action = 'login'$$,
  '42501',
  null,
  'activity logs cannot be modified by a driver'
);

-- ---------------------------------------------------------------------------
-- 3. Staff authorisation
-- ---------------------------------------------------------------------------
select pg_temp.login((select staff_auth from fx));

select cmp_ok(
  (select count(*)::int from public.profiles),
  '>=', 4,
  'staff can read profiles (own account plus the accounts under review)'
);

select is(
  (select count(*)::int from public.franchise_applications where id = (select id from fx_app)),
  1,
  'staff can read applications submitted by drivers'
);

select throws_ok(
  $$select public.rpc_admin_set_user_role((select driver2 from ids), 'administrator')$$,
  '42501',
  null,
  'staff cannot assign roles'
);

select throws_ok(
  $$select public.rpc_admin_set_account_status((select driver2 from ids), 'inactive', 'test')$$,
  '42501',
  null,
  'staff cannot deactivate accounts'
);

select throws_ok(
  $$update public.profiles set role = 'administrator' where id = (select staff from ids)$$,
  '42501',
  null,
  'staff cannot change their own role'
);

select throws_ok(
  $$update public.roles set label = 'Hacked' where code = 'administrator'$$,
  '42501',
  null,
  'the role catalogue cannot be modified from any client'
);

select throws_ok(
  $$select public.rpc_analytics_system_health()$$,
  '42501',
  null,
  'staff cannot read administrator-only system health analytics'
);

select lives_ok(
  $$select public.rpc_analytics_overview()$$,
  'staff can read operational analytics'
);

select lives_ok(
  $$select public.rpc_staff_start_review((select id from fx_app))$$,
  'staff can start reviewing an application'
);

select throws_ok(
  $$select public.rpc_staff_approve_application((select id from fx_app))$$,
  'P0001',
  null,
  'staff cannot approve an application whose documents are unverified'
);

select throws_ok(
  $$select public.rpc_staff_reject_application((select id from fx_app), 'too short')$$,
  'P0001',
  null,
  'a rejection reason shorter than 10 characters is refused'
);

-- ---------------------------------------------------------------------------
-- 4. Administrator authorisation
-- ---------------------------------------------------------------------------
select pg_temp.login((select admin_auth from fx));

select lives_ok(
  $$select public.rpc_admin_set_user_role((select driver2 from ids), 'staff')$$,
  'an administrator can assign an authorised role'
);

select throws_ok(
  $$select public.rpc_admin_set_user_role((select admin from ids), 'driver')$$,
  '42501',
  null,
  'an administrator cannot change their own role'
);

select throws_ok(
  $$select public.rpc_admin_set_user_role((select driver2 from ids), 'superuser'::public.user_role)$$,
  '22P02',
  null,
  'an invalid role value is rejected by the role enum'
);

select throws_ok(
  $$select public.rpc_admin_set_account_status((select admin from ids), 'inactive', 'test')$$,
  '42501',
  null,
  'an administrator cannot deactivate their own account'
);

select lives_ok(
  $$select public.rpc_admin_set_account_status((select driver1 from ids), 'inactive', 'Test suspension')$$,
  'an administrator can deactivate a driver account'
);

-- ---------------------------------------------------------------------------
-- 5. Deactivation is enforced by the database, not by the interface
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver1_auth from fx));

select is(
  (select count(*)::int from public.franchise_applications),
  0,
  'a deactivated driver can no longer read their own applications'
);

select is(
  public.current_profile_id(), null,
  'current_profile_id() returns NULL for a deactivated account'
);

-- ---------------------------------------------------------------------------
-- 6. Anonymous access
-- ---------------------------------------------------------------------------
select pg_temp.login(gen_random_uuid(), 'anon');

select is(
  (select count(*)::int from public.barangays), 34,
  'anonymous visitors can read the barangay reference list used by registration'
);

select is(
  (select count(*)::int from public.profiles), 0,
  'anonymous visitors cannot read profiles'
);

select is(
  (select count(*)::int from public.franchise_records), 0,
  'anonymous visitors cannot read franchise records'
);

select is(
  (select public.rpc_verify_certificate('ZZZZZZZZZZZZ')->>'verification_status'),
  'not_found',
  'certificate verification returns not_found for an unknown code'
);

-- ---------------------------------------------------------------------------
-- 7. Privilege surface
-- ---------------------------------------------------------------------------
reset role;

select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee in ('anon', 'authenticated')
      and table_schema = 'public'
      and table_name in ('franchise_number_sequences', 'renewal_reminders_sent')),
  0,
  'sequence and reminder bookkeeping tables grant nothing to client roles'
);

select is(
  (select count(*)::int
     from information_schema.column_privileges
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'profiles'
      and privilege_type = 'UPDATE'
      and column_name in ('role', 'account_status', 'status_reason', 'auth_user_id')),
  0,
  'privileged profile columns are not updatable by clients'
);

select is(
  (select count(*)::int
     from information_schema.column_privileges
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'franchise_applications'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'franchise_applications is read-only for clients (all writes go through RPCs)'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public' and tablename = 'activity_logs' and cmd in ('UPDATE', 'DELETE')),
  0,
  'no update or delete policy exists for activity_logs'
);

-- ---------------------------------------------------------------------------
-- 8. Audit immutability, Realtime and Storage configuration
-- ---------------------------------------------------------------------------
select throws_ok(
  $$update public.activity_logs set action = 'login' where id is not null$$,
  '42501',
  null,
  'the append-only trigger rejects audit-log updates even for the owner role'
);

select throws_ok(
  $$delete from public.activity_logs where id is not null$$,
  '42501',
  null,
  'the append-only trigger rejects audit-log deletions'
);

select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and tablename in ('notifications', 'franchise_applications', 'franchise_records', 'franchise_documents')),
  4,
  'the four user-facing tables are published for Realtime'
);

select is(
  (select count(*)::int from storage.buckets where id in ('franchise-documents', 'certificates') and public = false),
  2,
  'both storage buckets are private'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'documents bucket%'),
  4,
  'the document bucket exposes exactly four storage policies'
);

select * from finish();
rollback;
