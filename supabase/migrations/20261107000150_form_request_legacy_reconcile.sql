-- ===========================================================================
-- SBTF System — reconcile the request-form schema that was applied directly
-- to the project before this branch's migrations existed.
--
-- The earlier implementation required four request documents, snapshotted the
-- applicant as `applicant_full_name`, and consumed an issued request from an
-- AFTER INSERT trigger on `franchise_applications`. This branch's flow stores a
-- single OR/CR and signature on the request, rejects/resubmits the same row,
-- and consumes the request inside `rpc_driver_submit_application`.
--
-- This migration only removes the pieces that would conflict. It keeps the
-- legacy columns and the `form_request_documents` rows so no data is lost.
-- ===========================================================================

-- The driver submission RPC now consumes the request in its own transaction.
-- Leaving the old trigger in place would try to consume the same request a
-- second time and abort every submission.
drop trigger if exists trg_consume_issued_form_request on public.franchise_applications;

-- The old function is left in place (unused) so the static SQL validator can
-- resolve every reference; the trigger above is what actually consumed requests.

-- New requests populate `applicant_name`; legacy rows keep their snapshot in
-- `applicant_full_name`. Nullable keeps the old length check satisfied while
-- letting both shapes coexist.
alter table public.form_requests alter column applicant_full_name drop not null;

-- Rejection bookkeeping is `reviewed_by` / `reviewed_at` in this flow. The old
-- `rejected_at` / `rejected_by` columns stay for historical rows, but the
-- constraint that required them would reject every new rejection.
alter table public.form_requests drop constraint if exists form_requests_rejection_consistency;
