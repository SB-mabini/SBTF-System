-- ===========================================================================
-- SBTF System — fix: document verification/rejection timeline event
--
-- fn_trg_document_written() (migration 20260101090600) passed a CASE
-- expression as the second argument of public.fn_add_application_event():
--
--   perform public.fn_add_application_event(
--     new.application_id,
--     case when new.verification_status = 'verified'
--          then 'document_verified' else 'document_rejected' end,  -- type text!
--     coalesce(v_actor, new.verified_by),
--     v_label
--   );
--
-- A CASE whose branches are bare string literals has type text, and there is
-- no implicit cast from text to the public.application_event enum. The call
-- therefore failed at runtime with
--
--   42883: function public.fn_add_application_event(uuid, text, uuid, text)
--          does not exist
--
-- which rolled back the whole statement. That is why the staff "Verify" and
-- "Reject document" actions never completed: rpc_staff_verify_document() only
-- updates franchise_documents, and this trigger then aborted the transaction.
--
-- 20260101090600 is already applied to the live project, so the fix ships as a
-- new migration that recreates the trigger function (the notification CASE a
-- few lines below already casts to public.notification_type; this does the
-- same for the timeline event via a typed variable).
-- ===========================================================================

create or replace function public.fn_trg_document_written()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor     uuid := public.current_profile_id();
  v_applicant uuid;
  v_app_number text;
  v_label     text;
  v_event     public.application_event;
begin
  select applicant_id, application_number into v_applicant, v_app_number
    from public.franchise_applications where id = new.application_id;

  v_label := replace(new.document_type::text, '_', ' ');

  if tg_op = 'INSERT' then
    perform public.fn_add_application_event(new.application_id, 'document_uploaded', v_actor, v_label);
    perform public.fn_log_activity(
      coalesce(v_actor, v_applicant),
      'document_upload',
      'franchise_document',
      new.id,
      jsonb_build_object('application_number', v_app_number, 'document_type', new.document_type)
    );
    perform public.fn_notify_staff_and_admin(
      'Document uploaded',
      v_label || ' was uploaded for application ' || v_app_number || '.',
      'application_submitted',
      'franchise_document',
      new.id
    );
    return new;
  end if;

  -- UPDATE: a replaced file is recorded before verification transitions.
  if new.storage_path is distinct from old.storage_path then
    perform public.fn_add_application_event(new.application_id, 'document_replaced', v_actor, v_label);
    perform public.fn_log_activity(
      coalesce(v_actor, v_applicant),
      'document_replaced',
      'franchise_document',
      new.id,
      jsonb_build_object('application_number', v_app_number, 'document_type', new.document_type)
    );
  end if;

  if new.verification_status is not distinct from old.verification_status then
    return new;
  end if;

  if new.verification_status = 'pending' then
    perform public.fn_add_application_event(new.application_id, 'document_replaced', v_actor, v_label || ' verification reset');
    return new;
  end if;

  v_event := (case when new.verification_status = 'verified'
                   then 'document_verified'
                   else 'document_rejected'
              end)::public.application_event;

  perform public.fn_add_application_event(
    new.application_id,
    v_event,
    coalesce(v_actor, new.verified_by),
    v_label
  );
  perform public.fn_log_activity(
    coalesce(v_actor, new.verified_by),
    'document_verification',
    'franchise_document',
    new.id,
    jsonb_build_object(
      'application_number', v_app_number,
      'document_type', new.document_type,
      'verification_status', new.verification_status,
      'remarks', new.remarks
    )
  );
  perform public.fn_notify(
    v_applicant,
    case when new.verification_status = 'verified' then 'Document verified' else 'Document needs attention' end,
    initcap(v_label) ||
    case when new.verification_status = 'verified'
         then ' was verified for application ' || v_app_number || '.'
         else ' was rejected for application ' || v_app_number || '. ' || coalesce('Remarks: ' || new.remarks, 'Please upload a corrected copy.')
    end,
    case when new.verification_status = 'verified'
         then 'document_verified'::public.notification_type
         else 'document_rejected'::public.notification_type end,
    'franchise_application',
    new.application_id
  );

  return new;
end;
$$;
