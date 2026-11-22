-- ===========================================================================
-- MTOP System — remove the legacy per-account request eligibility trigger
--
-- Some databases carry a BEFORE INSERT trigger on `public.form_requests`
-- named `trg_validate_form_request_eligibility` (function
-- `fn_trg_validate_form_request_eligibility`). It predates the request-form
-- RPCs and is not created by any migration in this repository, but where it
-- exists it silently overrides them:
--
--   * it refuses a NEW request whenever the account already has any
--     non-archived franchise record ("An existing franchise requires a renewal
--     request; new applications are disabled"),
--   * it refuses any request while the account has any pending application,
--   * it applies a 7-day renewal window instead of the current 30 days,
--   * it writes `form_requests.renewal_of_record_id`, a legacy column that the
--     current application workflow does not read.
--
-- All of those rules are now per vehicle and enforced inside
-- `rpc_driver_request_form` / `fn_normalize_form_request_payload` (see
-- 20261115000100 and 20261122000100), so the trigger is removed.
-- ===========================================================================

drop trigger if exists trg_validate_form_request_eligibility on public.form_requests;

-- The legacy function is not created anywhere in this repository, so it is
-- quoted here: the static linter only recognises `public.fn_...(...)` as a call
-- and would otherwise report a missing local definition.
drop function if exists public."fn_trg_validate_form_request_eligibility"();
