-- ===========================================================================
-- SBTF System — Request-form-first workflow (part 4)
-- Form-request notification and audit triggers for the new review outcomes:
-- rejection, resubmission and conversion. The existing insert / issue paths are
-- preserved and only their driver-facing wording is updated.
-- ===========================================================================

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
        'toda', v_toda,
        'review_due_at', new.review_due_at
      )
    );

    perform public.fn_notify_staff_and_admin(
      'New form request',
      'Form request ' || new.form_number || ' was submitted for a ' || new.application_type ||
        ' franchise' || coalesce(' (' || v_toda || ')', '') || '.' ||
        coalesce(' Review by ' || to_char(new.review_due_at, 'FMMon FMDD, YYYY FMHH12:MI AM') || '.', ''),
      'form_request_received',
      'form_request',
      new.id
    );

    return new;
  end if;

  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'issued' then
    perform public.fn_log_activity(
      coalesce(v_actor, new.issued_by),
      'form_request_issued',
      'form_request',
      new.id,
      jsonb_build_object('form_number', new.form_number)
    );

    perform public.fn_notify(
      new.requested_by,
      'Form request approved',
      'Your form request ' || new.form_number ||
        ' has been approved by staff. You may now complete your franchise application in the app.',
      'form_request_issued',
      'form_request',
      new.id
    );
  elsif new.status = 'rejected' then
    perform public.fn_log_activity(
      coalesce(v_actor, new.reviewed_by),
      'form_request_rejected',
      'form_request',
      new.id,
      jsonb_build_object(
        'form_number', new.form_number,
        'reason', new.rejection_reason
      )
    );

    perform public.fn_notify(
      new.requested_by,
      'Form request needs changes',
      'Your form request ' || new.form_number || ' was returned by staff: ' ||
        coalesce(new.rejection_reason, 'please review the details and resubmit.'),
      'form_request_rejected',
      'form_request',
      new.id
    );
  elsif old.status = 'rejected' and new.status = 'requested' then
    perform public.fn_log_activity(
      coalesce(v_actor, new.requested_by),
      'form_request_resubmitted',
      'form_request',
      new.id,
      jsonb_build_object('form_number', new.form_number, 'review_due_at', new.review_due_at)
    );

    perform public.fn_notify_staff_and_admin(
      'Form request resubmitted',
      'Form request ' || new.form_number || ' was corrected and resubmitted for review.',
      'form_request_resubmitted',
      'form_request',
      new.id
    );
  elsif new.status = 'converted' then
    perform public.fn_log_activity(
      coalesce(v_actor, new.requested_by),
      'form_request_converted',
      'form_request',
      new.id,
      jsonb_build_object(
        'form_number', new.form_number,
        'application_id', new.converted_application_id
      )
    );
  end if;

  return new;
end;
$$;

comment on function public.fn_trg_form_request_written() is
  'Audit + notification trigger for form requests: creation, approval, rejection, resubmission and conversion.';
