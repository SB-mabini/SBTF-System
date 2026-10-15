# Testing Plan — Phase 1 & 2 Acceptance

Acceptance tests for the web console (administrator + staff) and the database
workflow. Phase 3 (mobile) cases live in [`mobile.md`](./mobile.md).

**How to record results:** copy each table into the test record, fill **Actual**
with what happened and **Pass** with ✓ / ✗. The columns are intentionally empty
here — this file is the plan, not the record.

**Environment:** a Supabase project with all 20 migrations applied
([`deployment.md`](./deployment.md) §2.2) and the demonstration dataset loaded (§3
below). Static checks that need no database: `npm run validate:sql`,
`npm run test:verify`, `npm run web:test`.

---

## 1. Accounts used

| Role | Account | Source |
|---|---|---|
| administrator | `admin@mabini-sbtf.test` | seed (§3) |
| staff | `staff1@mabini-sbtf.test` | seed (§3) |
| driver | any `driverNNN@mabini-sbtf.test` | seed (§3) |
| fresh administrator | created via `supabase/first_admin.sql` | deployment §2.3 |

Passwords for the seeded accounts are documented in [`deployment.md`](./deployment.md) §6.

---

## 2. Preconditions checklist

| # | Check | Command / place |
|---|---|---|
| 1 | Migrations applied (20 files) | `npm run db:check` steps 4–5 |
| 2 | RLS enforced for the anon key | `npm run db:check` step 8 |
| 3 | Edge Function `admin-users` deployed | `supabase functions list` |
| 4 | `SITE_URL` secret set on the project | `supabase secrets list` |
| 5 | Web app running with `NEXT_PUBLIC_DEMO_MODE` unset | `apps/web/.env.local` |

---

## 3. Loading the seed data

Paste the **entire** `supabase/seed.sql` into the SQL Editor and run it (or use
`npm run db:bundle:seed` and paste the bundle). Notes:

- The file is wrapped in its own transaction: it either loads completely or not at all.
- It is **additive and idempotent** — accounts are matched on e-mail, so re-running
  never duplicates them.
- It **never touches the viewer's own account**: every seeded account lives under
  `@mabini-sbtf.test`, and cleanup (if ever needed) can be scoped to that domain.
- Do not run it against the production project. It is synthetic data.

---

## 4. Four seeded-data traps

These look like bugs but are properties of the dataset. Read before logging defects.

| # | Trap | Why |
|---|---|---|
| 1 | **Document files do not exist.** Opening a seeded document shows nothing / a broken signed URL. | The seed creates `franchise_documents` rows with synthetic `storage_path`s; no file was ever uploaded to the storage bucket. Verify the *row* and the *workflow*, not the file. |
| 2 | **No certificates on seeded records.** Seeded franchise records have no certificate to download. | The seed does not generate certificate PDFs (`certificate_storage_path` is null). Certificate generation must be tested on a record approved during the test run. |
| 3 | **Dates are fixed around 2026-01-05.** The seed's reference date is 2026-01-05 (generator: `scripts/generate_seed.py`). | Analytics windows ("last 30 days"), expiry buckets and trends are computed relative to *now*, so seeded volumes drift as real time passes. Compare against the cross-check SQL (§8), not against the dashboard's implied freshness. |
| 4 | **Reviewer attribution is deterministic, not personal.** Seeded verifications/rejections are attributed to whichever staff account the generator assigned (`ordinal % 4`). | Do not read attribution in seeded rows as evidence about a real person's actions. Attribution performed *during* this test run is the only meaningful kind. |

---

## 5. Administrator cases (A-01 … A-17)

| ID | Action | Expected result | Actual | Pass |
|---|---|---|---|---|
| A-01 | Sign in as administrator | Lands on `/admin`; login written to the activity log | | |
| A-02 | Open the dashboard | Overview counts match the cross-check SQL (§8) for totals, pending, approved, rejected | | |
| A-03 | Open analytics | Trend, TODA, processing-time and compliance panels render; prescriptive indicators each carry a finding, recommendation and data basis | | |
| A-04 | Generate the AI advisory | Advisory renders with the "For Decision Support Only" banner; request logged in `ai_request_logs` | | |
| A-05 | Filter and paginate the applications list | Status/type/TODA filters and pagination hold across navigation | | |
| A-06 | Open an application detail | Documents, applicant, TODA and timeline render; timeline shows `created` and per-document events | | |
| A-07 | Verify a pending document as verified | Status flips to verified; `document_verified` event on the timeline; notification to the driver | | |
| A-08 | Reject a document with a remark < 5 characters | Refused with the minimum-length message; at ≥ 5 characters it succeeds and resets approval of the application | | |
| A-09 | **Create a staff account** (Users → Create account) | Account created; the dialog shows a password-setup link; **no e-mail is sent or claimed** | | |
| A-09b | **Open the setup link** | First use: password set succeeds, sign-in works. Second use of the same link: refused (single-use) | | |
| A-09c | **Call create-staff with the Edge Function undeployed** | Loud failure naming the missing function; **no partial account** exists in `auth.users` afterwards | | |
| A-10 | Approve a fully verified application | Status becomes approved; franchise number `MAB-TR-YYYY-NNNNNN` issued; record linked; driver notified | | |
| A-11 | Reject an application | Reason ≥ 10 characters required; shorter refused; the stored reason appears in the driver notification | | |
| A-12 | Change a user's role / deactivate an account | Both refused for your own account; deactivation requires a reason ≥ 5 characters and bans the auth session; reactivation restores it | | |
| A-13 | Send password reset for a user | A single-use reset link is returned in the console with a copy button; nothing is e-mailed | | |
| A-14 | Review the activity log | Every action above appears with actor, action and target; driver rows are not visible in full (scoped RLS) | | |
| A-15 | Edit system settings | Value updates persist, are validated by type, and each change is written to the activity log | | |
| A-16 | Generate and attach a certificate for an approved record | PDF generated client-side, uploaded to the `certificates` bucket under the staff member's folder, linked to the record | | |
| A-17 | Export reports | CSV export downloads; columns match the on-screen table; no rows the role cannot see | | |

---

## 6. Staff cases (S-01 … S-17)

| ID | Action | Expected result | Actual | Pass |
|---|---|---|---|---|
| S-01 | Sign in as staff | Lands on `/staff`, not `/admin` | | |
| S-02 | Navigate to `/admin` directly | Redirected to `/staff`; nothing rendered | | |
| S-03 | View the applications queue | Pending applications listed with age and TODA; filters work | | |
| S-04 | Start a review on a pending application | `review_started` recorded; application locked to the reviewer flow | | |
| S-05 | Verify all four documents of one application | All verified; approval becomes possible only after the last one | | |
| S-06 | Reject one document with a proper remark | Document rejected; driver notified with the remark; replacement upload by the driver resets it to pending (migration 14 RPC) | | |
| S-07 | Approve the verified application | Franchise record issued; certificate number follows the format; timeline complete | | |
| S-08 | Reject another application with a reason | Reason stored verbatim; no record issued; driver sees the reason | | |
| S-09 | Open a franchise record detail | Operator, TODA, dates and verification code render; QR encodes only the code | | |
| S-10 | Archive a franchise record with a reason | Record archived; public verification now answers `archived`; reason required | | |
| S-11 | Attach a certificate to a record | Upload confined to the caller's storage folder; `certificate_generated_at` stamped | | |
| S-12 | Verify a certificate anonymously (`/verify?code=…`) | Works signed out; operator name masked; unknown code answers `not_found` | | |
| S-13 | Notifications | Submission/approval/rejection notifications arrive in-app and mark as read | | |
| S-14 | Staff analytics | Operational panels render; administrator-only system health is not offered | | |
| S-15 | Attempt user management | No create/deactivate controls; the RPCs refuse a staff caller (42501) | | |
| S-16 | Attempt to edit system settings | Refused — settings updates are administrator-only | | |
| S-17 | Renewal reminders view | Expiring records listed in the correct buckets; reminder history matches `renewal_reminders_sent` | | |

---

## 7. Security cases (X-01 … X-08)

Run these against the live project with `curl` / the SQL Editor, not through the UI —
the point is that the database enforces the rules even when the interface is bypassed.

| ID | Action | Expected result | Actual | Pass |
|---|---|---|---|---|
| X-01 | Query `profiles`, `franchise_applications`, `franchise_documents` with the anon key | Empty results or 401/403 — never rows | | |
| X-02 | As driver A, select driver B's documents through PostgREST | Zero rows — RLS returns only the caller's own application documents | | |
| X-03 | As staff, call `rpc_admin_set_user_role` / `rpc_admin_set_account_status` | Refused with 42501 | | |
| X-04 | Self-register supplying `role: administrator` in user metadata | Profile is created as `driver` — role comes from app metadata, which clients cannot write | | |
| X-05 | Storage probes: download an object without a signature; upload outside `{profile_id}/` | Both refused; the RPC also rejects paths outside the caller's folder | | |
| X-06 | Try to replace a **verified** document via `rpc_driver_replace_document`, and try to verify a document on an already-decided application | Both refused with P0001. Verification columns (`verification_status`, `verified_by`, `verified_at`, `remarks`) are additionally excluded from the PostgREST column grants, so no client can write them directly | | |
| X-07 | Deactivate the last active administrator; change your own role | Both refused by the RPCs | | |
| X-08 | `rpc_verify_certificate` with a valid code | Response carries only the masked operator name, TODA, dates and status — no contact details, no full name | | |

---

## 8. Cross-check SQL

Run after the cases above and compare with the dashboards. Adjust the date window to
the seed reference date (§4 trap 3) when working with seeded data.

```sql
-- Application totals by status
select status, count(*) from public.franchise_applications group by status;

-- Documents by verification status
select verification_status, count(*) from public.franchise_documents group by 1;

-- Active vs expiring franchise records
select
  count(*) filter (where not archived and expires_at > now())             as active,
  count(*) filter (where expires_at between now() and now() + interval '90 days') as expiring_90,
  count(*) filter (where expires_at <= now())                             as expired
from public.franchise_records;

-- Audit trail integrity: every decided application has timeline + activity rows
select a.id, a.application_number,
       exists (select 1 from public.application_status_history h
                where h.application_id = a.id and h.event = a.status::text::public.application_event) as has_event
from public.franchise_applications a
where a.status in ('approved', 'rejected');
```

---

## 9. Email, password recovery and one-time password

Self-service password recovery, driver one-time passwords, and the staff-approval gate
are covered here. Configuration lives in [`deployment.md`](./deployment.md) §3.1; the
templates are `supabase/templates/recovery.html` and `supabase/templates/magic_link.html`.

Use only addresses you can actually open (for example the configured Gmail account). The
seeded `@mabini-sbtf.test` accounts cannot receive mail.

### 9.1 Readiness checklist

All must be true before running the cases, or the first error is configuration, not a
defect.

| # | Check | Where |
|---|---|---|
| 1 | Custom SMTP saved (Gmail + App Password) and a **test e-mail arrives** | Dashboard → Authentication → Emails → SMTP Settings |
| 2 | Site URL is the origin under test, and `/auth/confirm` is in the redirect allow-list | Dashboard → Authentication → URL Configuration |
| 3 | Reset Password template uses `{{ .TokenHash }}` (copied from `recovery.html`); Magic Link template contains `{{ .Token }}` | Dashboard → Authentication → Email Templates |
| 4 | `password-recovery` Edge Function deployed with **Verify JWT off** | Dashboard → Edge Functions |
| 5 | `SITE_URL` function secret set to the origin under test | `supabase secrets list` |
| 6 | `NEXT_PUBLIC_SUPABASE_URL` is the deployed project and `NEXT_PUBLIC_SITE_URL` matches the Site URL | `apps/web/.env.local` |

### 9.2 Cases (E-01 … E-07)

| ID | Action | Expected result | Actual | Pass |
|---|---|---|---|---|
| E-01 | **Forgot your password?** with an administrator's address | Generic "Request accepted" — never reveals whether the account exists; recovery e-mail arrives | | |
| E-02 | Same with an **active staff** address | Same generic response; recovery e-mail arrives | | |
| E-03 | Same with a **pending staff** address | Same generic response; **no** e-mail is sent | | |
| E-04 | Same with a **driver/operator** address | Same generic response; **no** e-mail is sent (drivers use the mobile OTP) | | |
| E-05 | Open the recovery e-mail link | Lands on `/reset-password`; setting a password succeeds and sign-in works with it | | |
| E-06 | Re-open the same recovery link | Refused — single-use/expired; lands on `/auth/confirmed?status=invalid` | | |
| E-07 | Mobile: "Sign in with one-time password" | 6-digit code arrives; entering it signs the driver in | | |

### 9.3 Failure triage

The "Forgot your password?" error line reports the real cause.

| Symptom | Cause |
|---|---|
| `HTTP 404` | `password-recovery` not deployed, or `NEXT_PUBLIC_SUPABASE_URL` points at a different project |
| `HTTP 401` | Verify JWT still on for `password-recovery` |
| `HTTP 500` | Function runtime error — read the function logs |
| Fetch/network error | Wrong project URL, or Supabase unreachable |
| E-02 e-mail never arrives | SMTP not saved/verified, or the Gmail App Password is wrong |
| E-05 lands on `/auth/confirmed?status=invalid` | Template still uses `{{ .ConfirmationURL }}`, or Site URL / redirect allow-list mismatch |

Logs: Dashboard → Edge Functions → `password-recovery` → Logs.

### 9.4 Staff create + approve (needs the `pending` migration)

Apply `supabase/migrations/20260101091400_pending_account_status.sql` and redeploy
`admin-users` before this flow, otherwise `create_staff` fails when it sets `pending`.

1. Create a staff account → the row shows **Awaiting approval**.
2. **Approve account** → status becomes active.
3. **Send password reset** → the console returns a link (handover by design,
   §3.1d of `deployment.md`). Once active, the staff member can also self-serve from
   `/forgot-password`.

---

## 10. Automated checks (no database needed)

| Command | Gate |
|---|---|
| `npm run validate:sql` | 504 statements parse with the real PostgreSQL grammar, 0 errors |
| `npm run test:verify` | 10 assertions: the live verifier passes a healthy mock and fails — naming RPC and field — on a renamed analytics column |
| `npm run web:test` | Web unit tests (error classification, formatting, permissions, demo fixtures, certificate helpers) |

---

## 11. Recording convention

- One run per environment; note the project ref, commit and date at the top of the record.
- ✗ results get a linked screenshot or the exact error message in **Actual**.
- A case blocked by a known gap (§12) is marked **blocked**, not ✗, with the gap id.

---

## 12. Gap list

Known holes, current status. Items move out of this list only with a code reference.

| # | Gap | Status |
|---|---|---|
| 1 | **Drivers could not replace a rejected document** — no upload path existed after staff rejection. | **Resolved** by migration 14 (`20260101091300`, `rpc_driver_replace_document`); covered by pgTAP section 3a of `supabase/tests/02_workflow.sql`. Mobile UI for it arrives in slice 5. |
| 2 | Staff invitations hand over a link in the console instead of e-mailing it. | Open by design — the account is `pending` until approved, so a single-use link sent at creation would expire first. Self-service recovery and driver OTP **do** send mail through the project's Gmail SMTP ([deployment.md §3.1](./deployment.md)). |
| 3 | pgTAP suites (`npm run test:rls`) are not executed in CI — they need a Supabase project. | Open; run by hand before releases. |
| 4 | Mobile application slices 3–8 (submission, tracking, uploads, certificate, notifications) not built yet. | Open — see [mobile.md](./mobile.md) §7. |
| 5 | Scheduled renewal job registration on a brand-new project is not automated. | Open; confirm after deploy ([deployment.md §9](./deployment.md)). |
