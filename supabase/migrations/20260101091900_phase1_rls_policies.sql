-- ===========================================================================
-- SBTF System — Phase 1.5
-- Row Level Security and privilege grants for the Phase 1 workflow tables.
--
-- Same design rules as Phase 0: clients get SELECT only; every write moves
-- through a validated SECURITY DEFINER RPC. Administrators keep read-only
-- visibility of applications and records; staff perform the handling actions.
-- ===========================================================================

-- --- enable RLS -------------------------------------------------------------
alter table public.form_requests              enable row level security;
alter table public.application_appointments   enable row level security;
alter table public.document_releases          enable row level security;

-- ---------------------------------------------------------------------------
-- form_requests
-- ---------------------------------------------------------------------------
drop policy if exists "form_requests: drivers read their own requests" on public.form_requests;
create policy "form_requests: drivers read their own requests"
  on public.form_requests for select to authenticated
  using (requested_by = public.current_profile_id());

drop policy if exists "form_requests: staff and administrators read all requests" on public.form_requests;
create policy "form_requests: staff and administrators read all requests"
  on public.form_requests for select to authenticated
  using (public.is_staff_or_admin());

-- ---------------------------------------------------------------------------
-- application_appointments
-- ---------------------------------------------------------------------------
drop policy if exists "appointments: drivers read their own appointments" on public.application_appointments;
create policy "appointments: drivers read their own appointments"
  on public.application_appointments for select to authenticated
  using (
    exists (
      select 1 from public.franchise_applications a
       where a.id = application_id
         and a.applicant_id = public.current_profile_id()
    )
  );

drop policy if exists "appointments: staff and administrators read all appointments" on public.application_appointments;
create policy "appointments: staff and administrators read all appointments"
  on public.application_appointments for select to authenticated
  using (public.is_staff_or_admin());

-- ---------------------------------------------------------------------------
-- document_releases
-- ---------------------------------------------------------------------------
drop policy if exists "document_releases: drivers read their own releases" on public.document_releases;
create policy "document_releases: drivers read their own releases"
  on public.document_releases for select to authenticated
  using (
    exists (
      select 1 from public.franchise_applications a
       where a.id = application_id
         and a.applicant_id = public.current_profile_id()
    )
  );

drop policy if exists "document_releases: staff and administrators read all releases" on public.document_releases;
create policy "document_releases: staff and administrators read all releases"
  on public.document_releases for select to authenticated
  using (public.is_staff_or_admin());

-- ===========================================================================
-- Privilege grants
-- ===========================================================================

-- Least privilege for the new tables: read-only for clients.
revoke all on table public.form_requests, public.application_appointments, public.document_releases
  from anon, authenticated;

grant select on table public.form_requests, public.application_appointments, public.document_releases
  to authenticated;

-- --- function execution privileges ------------------------------------------
-- Internal helper: never callable by a client role.
revoke all on function public.fn_staff_issue_franchise_record(uuid) from public, anon, authenticated;
revoke all on function public.fn_trg_application_stage_changed() from public, anon, authenticated;
revoke all on function public.fn_trg_form_request_written() from public, anon, authenticated;
revoke all on function public.fn_trg_appointment_written() from public, anon, authenticated;
revoke all on function public.fn_trg_document_release_created() from public, anon, authenticated;

-- Staff workflow RPCs (each re-validates the caller's role internally).
grant execute on function public.rpc_staff_assign_application(uuid, uuid) to authenticated;
grant execute on function public.rpc_staff_request_compliance(uuid, text) to authenticated;
grant execute on function public.rpc_staff_mark_verified(uuid) to authenticated;
grant execute on function public.rpc_staff_record_application(uuid) to authenticated;
grant execute on function public.rpc_staff_record_endorsement(uuid, text, text, text) to authenticated;
grant execute on function public.rpc_staff_record_decision(uuid, text, text, text, text) to authenticated;
grant execute on function public.rpc_staff_release_document(uuid, text, text, text, text) to authenticated;
grant execute on function public.rpc_staff_complete_application(uuid) to authenticated;
grant execute on function public.rpc_staff_schedule_appointment(uuid, public.appointment_kind, timestamptz, text, text) to authenticated;
grant execute on function public.rpc_staff_update_appointment(uuid, public.appointment_status, text, timestamptz, text, text) to authenticated;
grant execute on function public.rpc_staff_issue_form_request(uuid) to authenticated;
grant execute on function public.rpc_staff_convert_form_request(uuid, uuid) to authenticated;

-- Driver form-request RPCs.
grant execute on function public.rpc_driver_request_form(jsonb) to authenticated;
grant execute on function public.rpc_driver_cancel_form_request(uuid, text) to authenticated;
