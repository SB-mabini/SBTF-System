-- ===========================================================================
-- SBTF System — guard: an application can be recorded only once
--
-- rpc_staff_record_application() (migration 20260101091700) only rejected
-- applications whose status was no longer 'pending'. It never looked at the
-- pipeline stage, so a second call on an application already at stage
-- 'recorded' would run again: fn_staff_issue_franchise_record() returns the
-- existing record (so no duplicate franchise number), but the stage update and
-- its timeline/notification side effects fired a second time. The button is
-- only drawn at stage 'verified', but the database is the authority.
--
-- This recreation adds an explicit stage guard so recording only ever proceeds
-- from 'verified'. A repeat call is refused with a clear message instead of
-- silently re-stamping the application.
-- ===========================================================================

create or replace function public.rpc_staff_record_application(p_application_id uuid)
returns public.franchise_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_app         public.franchise_applications;
  v_record      public.franchise_records;
  v_outstanding integer;
begin
  if not public.is_staff() then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select * into v_app from public.franchise_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if v_app.status <> 'pending' then
    raise exception 'This application has already been %', v_app.status using errcode = 'P0001';
  end if;

  if v_app.stage <> 'verified' then
    raise exception 'Only a verified application can be recorded (current stage: %)', v_app.stage
      using errcode = 'P0001';
  end if;

  select count(*) into v_outstanding
    from unnest(enum_range(null::public.document_type)) as dt
   where not exists (
           select 1 from public.franchise_documents d
            where d.application_id = v_app.id
              and d.document_type = dt
              and d.verification_status = 'verified'
         );

  if v_outstanding > 0 then
    raise exception 'Cannot record yet: % documentary requirement(s) are still unverified',
      v_outstanding using errcode = 'P0001';
  end if;

  v_record := public.fn_staff_issue_franchise_record(v_app.id);

  update public.franchise_applications
     set stage = 'recorded'
   where id = v_app.id;

  return v_record;
end;
$$;
