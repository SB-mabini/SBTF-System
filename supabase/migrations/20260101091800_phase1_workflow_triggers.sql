-- ===========================================================================
-- SBTF System — Phase 1.4
-- Triggers for the Phase 1 workflow tables and the application pipeline.
--
-- Same division of responsibility as Phase 0: triggers own the audit trail,
-- the application timeline and notifications for every table mutation, so the
-- RPCs in the previous migration never duplicate those rows.
--
-- The stage trigger deliberately ignores transitions that also changed
-- `status`: those are the approve/reject transitions already handled by
-- fn_trg_application_status_changed(), which keeps the timeline unambiguous.
-- ===========================================================================

-- --- franchise_applications: pipeline stage changed -------------------------
create or replace function public.fn_trg_application_stage_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_label text;
begin
  if new.stage is not distinct from old.stage then
    return new;
  end if;

  if new.status is distinct from old.status then
    return new;
  end if;

  v_label := initcap(replace(new.stage::text, '_', ' '));

  perform public.fn_add_application_event(new.id, 'stage_changed', v_actor, v_label);

  perform public.fn_log_activity(
    coalesce(v_actor, new.assigned_staff_id),
    'stage_changed',
    'franchise_application',
    new.id,
    jsonb_build_object('application_number', new.application_number, 'stage', new.stage)
  );

  perform public.fn_notify(
    new.applicant_id,
    'Application update',
    'Your application ' || new.application_number || ' is now at stage: ' || v_label || '.',
    'application_stage_changed',
    'franchise_application',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists trg_application_stage_changed on public.franchise_applications;
create trigger trg_application_stage_changed
  after update on public.franchise_applications
  for each row execute function public.fn_trg_application_stage_changed();

-- --- form_requests ----------------------------------------------------------
create or replace function public.fn_trg_form_request_written()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_toda  text;
begin
  if tg_op = 'INSERT' then
    select name into v_toda from public.todas where id = new.toda_id;

    perform public.fn_log_activity(
      coalesce(v_actor, new.requested_by),
      'form_request_created',
      'form_request',
      new.id,
      jsonb_build_object(
        'form_number', new.form_number,
        'application_type', new.application_type,
        'toda', v_toda
      )
    );

    perform public.fn_notify_staff_and_admin(
      'New form request',
      'Form request ' || new.form_number || ' was submitted for a ' || new.application_type ||
        ' franchise' || coalesce(' (' || v_toda || ')', '') || '.',
      'form_request_received',
      'form_request',
      new.id
    );

    return new;
  end if;

  if new.status is distinct from old.status and new.status = 'issued' then
    perform public.fn_log_activity(
      coalesce(v_actor, new.issued_by),
      'form_request_issued',
      'form_request',
      new.id,
      jsonb_build_object('form_number', new.form_number)
    );

    perform public.fn_notify(
      new.requested_by,
      'Form request issued',
      'Your form request ' || new.form_number || ' is ready to be claimed at the franchising office.',
      'form_request_issued',
      'form_request',
      new.id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_form_request_written on public.form_requests;
create trigger trg_form_request_written
  after insert or update on public.form_requests
  for each row execute function public.fn_trg_form_request_written();

-- --- application_appointments -----------------------------------------------
create or replace function public.fn_trg_appointment_written()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor        uuid := public.current_profile_id();
  v_applicant    uuid;
  v_app_number   text;
  v_label        text;
  v_when         text;
begin
  select applicant_id, application_number into v_applicant, v_app_number
    from public.franchise_applications where id = new.application_id;

  v_label := replace(new.kind::text, '_', ' ');
  v_when  := to_char(new.scheduled_at, 'FMMon FMDD, YYYY FMHH12:MI AM');

  if tg_op = 'INSERT' then
    perform public.fn_log_activity(
      v_actor,
      'appointment_scheduled',
      'appointment',
      new.id,
      jsonb_build_object(
        'application_number', v_app_number,
        'kind', new.kind,
        'scheduled_at', new.scheduled_at
      )
    );

    perform public.fn_add_application_event(
      new.application_id,
      'appointment_scheduled',
      v_actor,
      initcap(v_label) || ' scheduled for ' || v_when
    );

    perform public.fn_notify(
      v_applicant,
      'Appointment scheduled',
      'A ' || v_label || ' appointment is set for ' || v_when || ' at ' || new.venue || '.',
      'appointment_scheduled',
      'appointment',
      new.id
    );

    return new;
  end if;

  perform public.fn_log_activity(
    v_actor,
    'appointment_updated',
    'appointment',
    new.id,
    jsonb_build_object(
      'application_number', v_app_number,
      'kind', new.kind,
      'status', new.status
    )
  );

  if new.status is distinct from old.status and new.status in ('completed', 'no_show') then
    perform public.fn_add_application_event(
      new.application_id,
      'appointment_completed',
      v_actor,
      initcap(v_label) || ' ' || replace(new.status::text, '_', ' ')
    );
  end if;

  perform public.fn_notify(
    v_applicant,
    'Appointment updated',
    'Your ' || v_label || ' appointment is now "' || replace(new.status::text, '_', ' ') || '".',
    'appointment_updated',
    'appointment',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists trg_appointment_written on public.application_appointments;
create trigger trg_appointment_written
  after insert or update on public.application_appointments
  for each row execute function public.fn_trg_appointment_written();

-- --- document_releases ------------------------------------------------------
create or replace function public.fn_trg_document_release_created()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor      uuid := public.current_profile_id();
  v_applicant  uuid;
  v_app_number text;
  v_franchise  text;
begin
  select a.applicant_id, a.application_number, r.franchise_number
    into v_applicant, v_app_number, v_franchise
    from public.franchise_applications a
    join public.franchise_records r on r.id = new.record_id
   where a.id = new.application_id;

  perform public.fn_log_activity(
    coalesce(v_actor, new.released_by),
    'document_released',
    'document_release',
    new.id,
    jsonb_build_object(
      'application_number', v_app_number,
      'franchise_number', v_franchise,
      'received_by', new.received_by_name,
      'acknowledged', new.acknowledged
    )
  );

  perform public.fn_add_application_event(new.application_id, 'document_released', v_actor, v_franchise);

  perform public.fn_notify(
    v_applicant,
    'Franchise document released',
    'Franchise ' || coalesce(v_franchise, '') || ' was released and acknowledged.',
    'document_release_ready',
    'franchise_record',
    new.record_id
  );

  return new;
end;
$$;

drop trigger if exists trg_document_release_created on public.document_releases;
create trigger trg_document_release_created
  after insert on public.document_releases
  for each row execute function public.fn_trg_document_release_created();

-- --- audit visibility for the new target types ------------------------------
create or replace function public.fn_can_read_activity_log(
  p_log_user_id uuid,
  p_target_type public.log_target_type,
  p_target_id   uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    public.is_staff_or_admin()
    or p_log_user_id = public.current_profile_id()
    or (
      p_target_type = 'franchise_application'
      and exists (
        select 1 from public.franchise_applications a
         where a.id = p_target_id and a.applicant_id = public.current_profile_id()
      )
    )
    or (
      p_target_type = 'franchise_record'
      and exists (
        select 1 from public.franchise_records r
         where r.id = p_target_id and r.operator_id = public.current_profile_id()
      )
    )
    or (
      p_target_type = 'franchise_document'
      and exists (
        select 1
          from public.franchise_documents d
          join public.franchise_applications a on a.id = d.application_id
         where d.id = p_target_id and a.applicant_id = public.current_profile_id()
      )
    )
    or (
      p_target_type = 'form_request'
      and exists (
        select 1 from public.form_requests f
         where f.id = p_target_id and f.requested_by = public.current_profile_id()
      )
    )
    or (
      p_target_type = 'appointment'
      and exists (
        select 1
          from public.application_appointments ap
          join public.franchise_applications a on a.id = ap.application_id
         where ap.id = p_target_id and a.applicant_id = public.current_profile_id()
      )
    )
    or (
      p_target_type = 'document_release'
      and exists (
        select 1
          from public.document_releases dr
          join public.franchise_applications a on a.id = dr.application_id
         where dr.id = p_target_id and a.applicant_id = public.current_profile_id()
      )
    );
$$;
