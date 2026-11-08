-- ===========================================================================
-- SBTF System — Request-form-first workflow tests
--
-- Covers the full loop: submit a complete request, staff reject with a reason,
-- driver edits and resubmits the SAME row, staff approve, the driver submits
-- the application, the request converts, and vehicles/OR-CR carry over.
-- Also covers the hard gate and the staff review-deadline reminder.
-- ===========================================================================
begin;
create extension if not exists pgtap with schema extensions;

select plan(29);

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
    jsonb_build_object('first_name', 'Request', 'last_name', 'Tester', 'contact_number', '09173334444'),
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
  pg_temp.mk_user('fr.driver@test.local', 'driver')       as driver_auth,
  pg_temp.mk_user('fr.driver2@test.local', 'driver')      as driver2_auth,
  pg_temp.mk_user('fr.staff@test.local', 'staff')         as staff_auth;

create temporary table ids as
select
  (select id from public.profiles where auth_user_id = fx.driver_auth)  as driver,
  (select id from public.profiles where auth_user_id = fx.driver2_auth) as driver2,
  (select id from public.profiles where auth_user_id = fx.staff_auth)   as staff,
  (select id from public.todas order by code limit 1)                   as toda
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

create or replace function pg_temp.request_payload(p_driver uuid, p_toda uuid, p_tag text)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'application_type', 'new',
    'toda_id', p_toda::text,
    'purpose', 'Franchise application for tricycle ' || p_tag,
    'ctc_number', 'CTC-' || p_tag,
    'vehicle_make', 'Honda',
    'vehicle_model', 'TMX 155',
    'engine_number', 'ENG-' || p_tag,
    'chassis_number', 'CHS-' || p_tag,
    'plate_number', 'PLT ' || p_tag,
    'cr_number', 'CR-' || p_tag,
    'or_cr_storage_path', p_driver::text || '/form-requests/' || p_tag || '/or-cr.pdf',
    'or_cr_file_name', 'or-cr.pdf',
    'or_cr_mime_type', 'application/pdf',
    'or_cr_file_size_bytes', 250000,
    'signature_typed_name', 'Request Tester'
  );
$$;

create or replace function pg_temp.app_payload(p_toda uuid, p_driver uuid, p_tag text)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'application_type', 'new',
    'toda_id', p_toda::text,
    'operator_address_line', 'Purok 1, Request Street',
    'operator_barangay_code', '041016017',
    'vehicle_year', 2019,
    'vehicle_color', 'Blue',
    'seating_capacity', 5,
    'documents', (
      select jsonb_agg(jsonb_build_object(
               'document_type', dt.document_type::text,
               'storage_path', p_driver::text || '/pending/' || p_tag || '-' || dt.document_type::text || '.pdf',
               'file_name', dt.document_type::text || '.pdf',
               'file_size_bytes', 250000,
               'mime_type', 'application/pdf'))
        from unnest(enum_range(null::public.document_type)) as dt(document_type)
       where dt.document_type::text <> 'or_cr'
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- 1. Driver submits a complete request
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver_auth from fx));

select throws_ok(
  $$select public.rpc_driver_request_form(
      pg_temp.request_payload((select driver from ids), (select toda from ids), 'FR1') - 'ctc_number')$$,
  'P0001', null,
  'a request without a CTC number is refused'
);

select lives_ok(
  $$select public.rpc_driver_request_form(
      pg_temp.request_payload((select driver from ids), (select toda from ids), 'FR1'))$$,
  'a complete request with OR/CR and signature is accepted'
);

select is(
  (select status::text from public.form_requests where requested_by = (select driver from ids)),
  'requested',
  'a new request starts as requested'
);

select is(
  (select review_due_at > requested_at from public.form_requests
    where requested_by = (select driver from ids)),
  true,
  'the staff review deadline is recorded'
);

select throws_ok(
  $$select public.rpc_driver_request_form(
      pg_temp.request_payload((select driver from ids), (select toda from ids), 'FR1B'))$$,
  'P0001', null,
  'a driver may only have one open request'
);

select throws_ok(
  $$select public.rpc_staff_issue_form_request(
      (select id from public.form_requests where requested_by = (select driver from ids)))$$,
  '42501', null,
  'a driver cannot approve their own request'
);

-- ---------------------------------------------------------------------------
-- 2. Staff reject with a reason, driver edits the same row
-- ---------------------------------------------------------------------------
select pg_temp.login((select staff_auth from fx));

select throws_ok(
  $$select public.rpc_staff_reject_form_request(
      (select id from public.form_requests where requested_by = (select driver from ids)),
      'too short')$$,
  'P0001', null,
  'a rejection reason shorter than 10 characters is refused'
);

select lives_ok(
  $$select public.rpc_staff_reject_form_request(
      (select id from public.form_requests where requested_by = (select driver from ids)),
      'The OR/CR photo is blurry. Please upload a clearer copy.')$$,
  'staff can reject a request with a reason'
);

select is(
  (select status::text from public.form_requests where requested_by = (select driver from ids)),
  'rejected',
  'the request becomes rejected'
);

select is(
  (select rejection_reason from public.form_requests where requested_by = (select driver from ids)),
  'The OR/CR photo is blurry. Please upload a clearer copy.',
  'the rejection reason is stored'
);

select is(
  (select count(*)::int from public.notifications
    where user_id = (select driver from ids)
      and notification_type = 'form_request_rejected'),
  1,
  'the driver is notified about the rejection'
);

select pg_temp.login((select driver2_auth from fx));

select throws_ok(
  $$select public.rpc_driver_update_form_request(
      (select id from public.form_requests where requested_by = (select driver from ids)),
      pg_temp.request_payload((select driver2 from ids), (select toda from ids), 'FR2'))$$,
  '42501', null,
  'another driver cannot edit the request'
);

select pg_temp.login((select driver_auth from fx));

select lives_ok(
  $$select public.rpc_driver_update_form_request(
      (select id from public.form_requests where requested_by = (select driver from ids)),
      pg_temp.request_payload((select driver from ids), (select toda from ids), 'FR1C'))$$,
  'the owner can edit and resubmit a rejected request'
);

select is(
  (select status::text from public.form_requests where requested_by = (select driver from ids)),
  'requested',
  'resubmitting returns the same row to requested'
);

select is(
  (select rejection_reason from public.form_requests where requested_by = (select driver from ids)),
  null,
  'resubmitting clears the old rejection reason'
);

-- ---------------------------------------------------------------------------
-- 3. Staff approve, mark printed, driver submits the application
-- ---------------------------------------------------------------------------
select pg_temp.login((select staff_auth from fx));

select lives_ok(
  $$select public.rpc_staff_issue_form_request(
      (select id from public.form_requests where requested_by = (select driver from ids)))$$,
  'staff can approve and issue the resubmitted request'
);

select is(
  (select status::text from public.form_requests where requested_by = (select driver from ids)),
  'issued',
  'the request becomes issued'
);

select is(
  (select reviewed_by = (select staff from ids) from public.form_requests
    where requested_by = (select driver from ids)),
  true,
  'the reviewing staff member is recorded'
);

select lives_ok(
  $$select public.rpc_staff_mark_form_request_printed(
      (select id from public.form_requests where requested_by = (select driver from ids)))$$,
  'staff can mark the approved letter as printed'
);

select is(
  (select printed_at is not null from public.form_requests
    where requested_by = (select driver from ids)),
  true,
  'the printed marker is stored'
);

select pg_temp.login((select driver_auth from fx));

select lives_ok(
  $$select public.rpc_driver_submit_application(
      pg_temp.app_payload((select toda from ids), (select driver from ids), 'FR1'))$$,
  'an approved request unlocks application submission'
);

select is(
  (select a.plate_number from public.franchise_applications a
    where a.applicant_id = (select driver from ids) order by a.submitted_at desc limit 1),
  'PLT FR1C',
  'the application copies the vehicle plate from the approved request'
);

select is(
  (select count(*)::int from public.franchise_documents d
     join public.franchise_applications a on a.id = d.application_id
    where a.applicant_id = (select driver from ids) and d.document_type = 'or_cr'),
  1,
  'the OR/CR is attached from the request'
);

select is(
  (select status::text from public.form_requests where requested_by = (select driver from ids)),
  'converted',
  'the request is consumed by the submission'
);

-- ---------------------------------------------------------------------------
-- 4. Hard gate and staff review reminder
-- ---------------------------------------------------------------------------
select pg_temp.login((select driver2_auth from fx));

select throws_ok(
  $$select public.rpc_driver_submit_application(
      pg_temp.app_payload((select toda from ids), (select driver2 from ids), 'NONE'))$$,
  'P0001', null,
  'a driver with no approved request cannot submit an application'
);

select lives_ok(
  $$select public.rpc_driver_request_form(
      pg_temp.request_payload((select driver2 from ids), (select toda from ids), 'FR2'))$$,
  'a second driver can submit a request'
);

select set_config('role', 'postgres', true);

update public.form_requests
   set review_due_at = now() + interval '1 hour',
       review_reminder_sent_at = null
 where requested_by = (select driver2 from ids)
   and status = 'requested';

select is(
  (public.fn_check_form_request_review_sla() ->> 'reminders')::int,
  1,
  'the review-deadline monitor raises one reminder'
);

select set_config('role', 'authenticated', true);

select is(
  (select count(*)::int from public.notifications
    where user_id = (select staff from ids)
      and notification_type = 'form_request_review_reminder'),
  1,
  'staff are notified before the review deadline'
);

select is(
  (select status::text from public.form_requests
    where requested_by = (select driver2 from ids) and form_number like 'FR-%'),
  'requested',
  'the reminder does not change the request status'
);

select * from finish();
rollback;
