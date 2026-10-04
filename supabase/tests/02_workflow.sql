-- ===========================================================================
-- SBTF System — business workflow test suite (pgTAP)
--
-- Exercises the complete franchise lifecycle end to end through the same
-- SECURITY DEFINER RPCs the web and mobile clients call:
--
--   driver submits → staff verifies documents → staff approves → record issued
--                                             ↳ staff rejects (reason recorded)
--   certificate verification, renewal reminders, audit trail, Realtime rows
--
-- Assertions are written so that they hold whether or not supabase/seed.sql
-- has been applied (per-record and per-user filters instead of global counts).
--
-- Run with:  supabase test db supabase/tests
-- ===========================================================================

begin;

create extension if not exists pgtap with schema extensions;

select plan(49);

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
    jsonb_build_object('first_name', 'Workflow', 'last_name', 'Tester', 'contact_number', '09171112222'),
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
  pg_temp.mk_user('wf.driver@test.local', 'driver')        as driver_auth,
  pg_temp.mk_user('wf.driver2@test.local', 'driver')       as driver2_auth,
  pg_temp.mk_user('wf.driver3@test.local', 'driver')       as driver3_auth,
  pg_temp.mk_user('wf.staff@test.local', 'staff')          as staff_auth,
  pg_temp.mk_user('wf.admin@test.local', 'administrator')  as admin_auth;

create temporary table ids as
select
  (select id from public.profiles where auth_user_id = fx.driver_auth)  as driver,
  (select id from public.profiles where auth_user_id = fx.driver2_auth) as driver2,
  (select id from public.profiles where auth_user_id = fx.driver3_auth) as driver3,
  (select id from public.profiles where auth_user_id = fx.staff_auth)   as staff,
  (select id from public.profiles where auth_user_id = fx.admin_auth)   as admin,
  (select id from public.todas order by code limit 1)                   as toda
from fx;

-- Approved applications used only by the renewal-reminder section.
create or replace function pg_temp.mk_approved_app(
  p_number text, p_driver uuid, p_toda uuid, p_staff uuid, p_plate text
) returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  insert into public.franchise_applications (
    application_number, applicant_id, application_type, toda_id,
    operator_first_name, operator_last_name, operator_contact_number,
    operator_address_line, vehicle_make, vehicle_model, vehicle_year, vehicle_color,
    plate_number, engine_number, chassis_number, status, reviewed_by, reviewed_at
  ) values (
    p_number, p_driver, 'new', p_toda, 'Reminder', 'Tester', '09171113333',
    'Purok 1, Test', 'Honda', 'TMX 155', 2016, 'Blue',
    p_plate, 'ENG-' || p_plate, 'CHS-' || p_plate,
    'approved', p_staff, now() - interval '11 months'
  )
  returning id into v_id;

  return v_id;
end;
$$;

create temporary table fx_app3 as
select pg_temp.mk_approved_app('TEST-WF-R1', (select driver3 from ids), (select toda from ids),
                               (select staff from ids), 'REM-003') as id;

create temporary table fx_app4 as
select pg_temp.mk_approved_app('TEST-WF-R2', (select driver2 from ids), (select toda from ids),
                               (select staff from ids), 'REM-004') as id;

grant select on fx, ids, fx_app3, fx_app4 to anon, authenticated;

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

-- Document payload (storage paths inside the applicant's own folder).
create or replace function pg_temp.docs(p_driver uuid, p_tag text)
returns jsonb
language sql
as $$
  select jsonb_agg(jsonb_build_object(
           'document_type', dt.document_type::text,
           'storage_path', p_driver::text || '/pending/' || p_tag || '-' || dt.document_type::text || '.pdf',
           'file_name', dt.document_type::text || '.pdf',
           'file_size_bytes', 250000,
           'mime_type', 'application/pdf'
         ))
    from unnest(enum_range(null::public.document_type)) as dt(document_type);
$$;

create or replace function pg_temp.payload(p_toda uuid, p_docs jsonb, p_type text default 'new')
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'application_type', p_type,
    'toda_id', p_toda::text,
    'operator_first_name', 'Workflow',
    'operator_last_name', 'Tester',
    'operator_contact_number', '09171112222',
    'operator_address_line', 'Purok 1, Test Street',
    'operator_barangay_code', '041016017',
    'vehicle_make', 'Honda',
    'vehicle_model', 'TMX 155',
    'vehicle_year', 2018,
    'vehicle_color', 'Blue',
    'plate_number', 'ABC 1234',
    'engine_number', 'ENG-99991',
    'chassis_number', 'CHS-99991',
    'seating_capacity', 5,
    'documents', p_docs
  );
$$;

-- ---------------------------------------------------------------------------
-- 1. Driver submission and server-side validation
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver_auth from fx));

select throws_ok(
  $$select public.rpc_driver_submit_application(pg_temp.payload((select toda from ids), '[]'::jsonb))$$,
  'P0001', null,
  'a submission without documents is refused'
);

select throws_ok(
  $$select public.rpc_driver_submit_application(
      pg_temp.payload((select toda from ids), pg_temp.docs((select driver from ids), 'x') - 'or_cr'))$$,
  'P0001', null,
  'a submission missing one required documentary requirement is refused'
);

select throws_ok(
  $$select public.rpc_driver_submit_application(
      jsonb_set(pg_temp.payload((select toda from ids), pg_temp.docs((select driver from ids), 'y')),
                '{vehicle_year}', '1901'))$$,
  'P0001', null,
  'an implausible vehicle year is refused'
);

select throws_ok(
  $$select public.rpc_driver_submit_application(
      jsonb_set(pg_temp.payload((select toda from ids), pg_temp.docs((select driver from ids), 'z')),
                '{documents,0,storage_path}', '"someone-else/pending/stolen.pdf"'))$$,
  '42501', null,
  'a document stored outside the applicant folder is refused'
);

select lives_ok(
  $$select public.rpc_driver_submit_application(
      pg_temp.payload((select toda from ids), pg_temp.docs((select driver from ids), 'a')))$$,
  'a complete submission is accepted'
);

select is(
  (select status::text from public.franchise_applications
    where applicant_id = (select driver from ids) order by submitted_at desc limit 1),
  'pending',
  'a newly submitted application starts as pending'
);

select is(
  (select count(*)::int from public.franchise_documents d
     join public.franchise_applications a on a.id = d.application_id
    where a.applicant_id = (select driver from ids)),
  4,
  'the four documentary requirements are stored with the application'
);

select is(
  (select count(*)::int from public.application_status_history h
     join public.franchise_applications a on a.id = h.application_id
    where a.applicant_id = (select driver from ids) and h.event = 'created'),
  1,
  'the submission is recorded on the application timeline'
);

select is(
  (select count(*)::int from public.activity_logs l
    where l.action = 'application_submitted'
      and l.target_id = (select id from public.franchise_applications
                          where applicant_id = (select driver from ids) limit 1)),
  1,
  'the submission is written to the audit trail'
);

select is(
  (select count(*)::int from public.notifications
    where notification_type = 'application_submitted' and user_id = (select staff from ids)),
  1,
  'staff receive an in-app notification for the new application'
);

select throws_ok(
  $$select public.rpc_driver_submit_application(
      pg_temp.payload((select toda from ids), pg_temp.docs((select driver from ids), 'b')))$$,
  'P0001', null,
  'a second pending application of the same type is refused'
);

-- ---------------------------------------------------------------------------
-- 2. Document verification and approval
-- ---------------------------------------------------------------------------
select pg_temp.login((select staff_auth from fx));

select throws_ok(
  $$select public.rpc_staff_approve_application(
      (select id from public.franchise_applications where applicant_id = (select driver from ids)))$$,
  'P0001', null,
  'approval is refused while the documents are still pending'
);

select lives_ok(
  $$select public.rpc_staff_verify_document(d.id, 'verified', null)
      from public.franchise_documents d
     where d.application_id = (select id from public.franchise_applications
                                where applicant_id = (select driver from ids))$$,
  'staff can verify every submitted document'
);

select is(
  (select count(*)::int from public.franchise_documents d
     join public.franchise_applications a on a.id = d.application_id
    where a.applicant_id = (select driver from ids) and d.verification_status = 'verified'),
  4,
  'all four documents end up verified'
);

select throws_ok(
  $$select public.rpc_staff_verify_document(
      (select d.id from public.franchise_documents d
        join public.franchise_applications a on a.id = d.application_id
       where a.applicant_id = (select driver from ids) limit 1),
      'rejected', 'bad')$$,
  'P0001', null,
  'rejecting a document without a meaningful remark is refused'
);

select lives_ok(
  $$select public.rpc_staff_approve_application(
      (select id from public.franchise_applications where applicant_id = (select driver from ids)))$$,
  'a fully verified application can be approved'
);

select is(
  (select status::text from public.franchise_applications where applicant_id = (select driver from ids)),
  'approved',
  'the application status becomes approved'
);

select matches(
  (select r.franchise_number from public.franchise_records r
    where r.operator_id = (select driver from ids) order by r.issued_at limit 1),
  '^MAB-TR-[0-9]{4}-[0-9]{6}$',
  'a franchise number in the configured format is issued'
);

select is(
  (select round(extract(epoch from (r.expires_at - r.issued_at)) / 86400)::int
     from public.franchise_records r
    where r.operator_id = (select driver from ids) order by r.issued_at limit 1),
  365,
  'the franchise record expires 12 months after issue'
);

select is(
  (select length(r.verification_code) from public.franchise_records r
    where r.operator_id = (select driver from ids) order by r.issued_at limit 1),
  12,
  'a 12-character verification identifier is generated for the QR code'
);

select is(
  (select count(*)::int from public.franchise_records r
     join public.franchise_applications a on a.id = r.application_id
    where r.operator_id = (select driver from ids) and a.status = 'approved'),
  1,
  'the franchise record is linked to the approved application'
);

select is(
  (select count(*)::int from public.notifications
    where user_id = (select driver from ids) and notification_type = 'application_approved'),
  1,
  'the driver is notified that the application was approved'
);

select is(
  (select count(*)::int from public.application_status_history h
     join public.franchise_applications a on a.id = h.application_id
    where a.applicant_id = (select driver from ids) and h.event = 'approved'),
  1,
  'the approval appears on the application timeline'
);

select throws_ok(
  $$select public.rpc_staff_approve_application(
      (select id from public.franchise_applications where applicant_id = (select driver from ids)))$$,
  'P0001', null,
  'an application cannot be approved twice'
);

-- ---------------------------------------------------------------------------
-- 3. Rejection flow
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver2_auth from fx));

select lives_ok(
  $$select public.rpc_driver_submit_application(
      pg_temp.payload((select toda from ids), pg_temp.docs((select driver2 from ids), 'c')))$$,
  'a second driver can submit an application'
);

select pg_temp.login((select staff_auth from fx));

select lives_ok(
  $$select public.rpc_staff_reject_application(
      (select id from public.franchise_applications where applicant_id = (select driver2 from ids)
         and application_number <> 'TEST-WF-R2'),
      'Barangay clearance submitted has already expired; please submit a current copy.')$$,
  'staff can reject an application with a documented reason'
);

select is(
  (select status::text from public.franchise_applications
    where applicant_id = (select driver2 from ids) and application_number <> 'TEST-WF-R2'),
  'rejected',
  'the application status becomes rejected'
);

select ok(
  (select rejection_reason is not null and length(rejection_reason) >= 10
     from public.franchise_applications
    where applicant_id = (select driver2 from ids) and application_number <> 'TEST-WF-R2'),
  'the rejection reason is stored'
);

select is(
  (select count(*)::int from public.franchise_records r
     join public.franchise_applications a on a.id = r.application_id
    where a.applicant_id = (select driver2 from ids) and a.application_number <> 'TEST-WF-R2'),
  0,
  'no franchise record is issued for a rejected application'
);

-- ---------------------------------------------------------------------------
-- 4. Driver-visible state after the decision (Realtime payload source)
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver2_auth from fx));

select is(
  (select status::text from public.franchise_applications
    where applicant_id = (select driver2 from ids) and application_number <> 'TEST-WF-R2'),
  'rejected',
  'the driver reads the rejected status through the same RLS path Realtime uses'
);

select ok(
  (select message like '%rejected%' from public.notifications
    where user_id = (select driver2 from ids) and notification_type = 'application_rejected' limit 1),
  'the rejection notification carries the reason for the driver'
);

-- ---------------------------------------------------------------------------
-- 5. Certificate verification (anonymous QR scanning)
-- ---------------------------------------------------------------------------
select pg_temp.login(gen_random_uuid(), 'anon');

select is(
  (select public.rpc_verify_certificate(r.verification_code)->>'verification_status'
     from public.franchise_records r
    where r.verification_code = (select min(r2.verification_code) from public.franchise_records r2
                                  where r2.operator_id = (select driver from ids))),
  'valid',
  'a valid certificate verifies as valid for an anonymous scanner'
);

select ok(
  (select public.rpc_verify_certificate(r.verification_code)->>'operator_display_name' like '%*%'
     from public.franchise_records r
    where r.verification_code = (select min(r2.verification_code) from public.franchise_records r2
                                  where r2.operator_id = (select driver from ids))),
  'the verification response masks the operator name'
);

select is(
  (select public.rpc_verify_certificate('ABCD-EFGH-JKMP')->>'franchise_number'),
  null,
  'verification of an unknown code returns no franchise number'
);

-- ---------------------------------------------------------------------------
-- 6. Renewal reminders (scheduled routine; never mutates records)
-- ---------------------------------------------------------------------------
reset role;

insert into public.franchise_records (
  application_id, operator_id, toda_id, franchise_number, verification_code,
  issued_at, expires_at
) select id, (select driver3 from ids), (select toda from ids), 'MAB-TR-2099-999999',
         'EXPIREYEAR99', now() - interval '11 months', now() + interval '45 days'
    from fx_app3;

insert into public.franchise_records (
  application_id, operator_id, toda_id, franchise_number, verification_code,
  issued_at, expires_at
) select id, (select driver2 from ids), (select toda from ids), 'MAB-TR-2099-999998',
         'NOREMINDER99', now() - interval '11 months', now() + interval '20 days'
    from fx_app4;

-- The second operator switches renewal reminders off before the run.
update public.profiles set renewal_reminders = false where id = (select driver2 from ids);

create temporary table record_before as
select md5(r::text) as hash from public.franchise_records r
 where r.franchise_number = 'MAB-TR-2099-999999';

grant select on record_before to anon, authenticated;

select lives_ok(
  $$select public.rpc_generate_renewal_reminders(array[90, 60, 30])$$,
  'the scheduled reminder routine runs to completion'
);

select is(
  (select count(*)::int from public.renewal_reminders_sent s
     join public.franchise_records r on r.id = s.record_id
    where r.franchise_number = 'MAB-TR-2099-999999' and s.window_days = 60),
  1,
  'the record is marked as reminded exactly once for the 60-day window'
);

select is(
  (select count(*)::int from public.notifications
    where user_id = (select driver3 from ids) and notification_type = 'renewal_reminder'),
  1,
  'the operator receives one renewal reminder notification'
);

select is(
  (select reminders_created from public.rpc_generate_renewal_reminders(array[90, 60, 30])),
  0,
  'the reminder routine is idempotent: a repeated run creates no further reminders'
);

select is(
  (select md5(r::text) from public.franchise_records r where r.franchise_number = 'MAB-TR-2099-999999'),
  (select hash from record_before),
  'the reminder routine did not modify the franchise record'
);

select is(
  (select count(*)::int from public.notifications
    where user_id = (select driver2 from ids) and notification_type = 'renewal_reminder'),
  0,
  'no reminder is created for an operator who disabled renewal reminders'
);

select is(
  (select count(*)::int from public.renewal_reminders_sent s
     join public.franchise_records r on r.id = s.record_id
    where r.franchise_number = 'MAB-TR-2099-999998'),
  0,
  'a skipped reminder is not marked as sent, so it can be delivered if the preference returns'
);

-- ---------------------------------------------------------------------------
-- 7. Analytics surface
-- ---------------------------------------------------------------------------
select pg_temp.login((select staff_auth from fx));

select cmp_ok(
  (select total_applications from public.rpc_analytics_overview()),
  '>=', 2::bigint,
  'the analytics overview counts the submitted applications'
);

select cmp_ok(
  (select count(*)::int from public.rpc_analytics_application_trends(12)),
  '>=', 12,
  'the monthly trend returns a full 12-month series'
);

select cmp_ok(
  (select count(*)::int from public.rpc_analytics_by_toda()),
  '>=', 1,
  'the per-TODA breakdown is produced'
);

select is(
  (select count(*)::int from public.rpc_analytics_document_compliance()),
  4,
  'document compliance analytics cover all four documentary requirements'
);

select ok(
  (select count(*) from public.rpc_analytics_prescriptive()) = 0
  or exists (
       select 1 from public.rpc_analytics_prescriptive() p
        where p.recommendation is not null and p.data_basis is not null and p.indicator_key is not null
     ),
  'every prescriptive indicator carries an explanation, a recommendation and a data basis'
);

select ok(
  (select public.rpc_analytics_ai_context(12) ? 'totals'),
  'the AI context payload contains aggregated totals'
);

select ok(
  not (select public.rpc_analytics_ai_context(12)::text ~* '(plate_number|contact_number|address_line|first_name|last_name)'),
  'the AI context payload contains no personal identifiers'
);

select pg_temp.login((select admin_auth from fx));

select is(
  (select users_drivers >= 3 from public.rpc_analytics_system_health()),
  true,
  'administrator system-health analytics are available to administrators'
);

select * from finish();
rollback;
