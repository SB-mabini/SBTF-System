# Current State — Environment and Recent Work

Companion to [`STAFF-INVITATIONS-PLAN.md`](./STAFF-INVITATIONS-PLAN.md). This file records
what has **already been completed**, so the next person does not redo it or assume the
database is empty.

**Last updated:** 2026-10-15

---

## 1. Live environment

| Item | Value |
|---|---|
| Supabase project ref | `qdtmzgaxktebyhsxrgvf` |
| URL | `https://qdtmzgaxktebyhsxrgvf.supabase.co` |
| Branch | `main` |
| Local app | `npm run web:dev` → `http://localhost:3000` |
| Deployed web app | `https://sbtf-system.vercel.app` |
| Edge Functions live | `ai-decision-support` (Verify JWT ON), `password-recovery` (Verify JWT OFF) |
| Connectivity check | `npm run db:check` (script at `scripts/check-supabase.mjs`) |

`apps/web/.env.local` has `NEXT_PUBLIC_DEMO_MODE=false`, so the app runs against the real
project with real authentication. Demo mode is off **deliberately** — it must never be
enabled outside local UI review, since it disables all writes.

### ⚠️ Exposed credentials — rotate these

These were pasted into chat and must be rotated once the outstanding work is verified:

- Supabase **personal access token** (platform admin scope)
- **Database password**
- **Groq API key** (used by `ai-decision-support`; revoke at <https://console.groq.com/keys>)
- **Google App Password** for `sangguniangbayan.mabini.batangas@gmail.com` — pasted into chat
  on 26 October 2026 to unblock SMTP and currently live in the Supabase config. Create a
  replacement, save it, verify, then revoke this one at
  <https://myaccount.google.com/apppasswords>.

None is committed to the repository, but all are compromised by exposure. Treat rotation
as a required follow-up task, not optional.

The two account passwords (`admin-password`, `staff-password`) are also weak and were
user-supplied. They should be rotated via the account page.

---

## 2. Database

- **All 26 migrations applied** to the live project and matching remote history.
- 19 tables, 35 public RLS policies, 70 functions, 2 storage buckets.
- Each staff member and administrator keeps their latest AI briefing for 24 hours in
  `ai_briefings`; a new briefing replaces it.
- 34 barangays seeded as reference data (from migrations, **not** from `seed.sql`).
- **Seed data has never been applied** to any environment, by explicit user decision.

`supabase/seed.sql` remains untouched and unapplied. If it is ever run, note that it is
wrapped in `BEGIN`/`COMMIT` and creates synthetic accounts that would need cleanup
scoped to `@mabini-sbtf.test`. Real accounts are separate and would survive that cleanup.

---

## 3. Accounts created

Two real accounts exist. Both are `active` and **pre-confirmed** (created with
`email_confirm_at = now()`) because no SMTP was available at the time.

| Role | Email | Name | Contact | Barangay |
|---|---|---|---|---|
| `administrator` | `sangguniangbayan.mabini.batangas@gmail.com` | Christian Edjan Bacay | `09096121428` | `041016027` (San Teodoro) |
| `staff` | `edwinchristianedjanbacay143@gmail.com` | Edwin Edjan Bacay | `09096121428` | `041016027` |

Verified at creation time:

- [x] Both authenticate — `HTTP 200`, bearer token issued via the password grant endpoint
- [x] `raw_app_meta_data.role` correct on each (the profiles trigger reads role from app
      metadata, never user metadata, so a client cannot self-assign an elevated role)
- [x] `account_status = 'active'` with a valid `auth_user_id` link
- [x] One `auth.identities` row each
- [x] The temporary `provision_sbtf_account()` helper was dropped — confirmed absent

These accounts predate the invitation feature. They are **not** pending and are unaffected
by that work.

---

## 4. Branding — done

Commit `cfd74af`, "feat: replace SBTF text monogram with the municipal logo".

The logo in `apps/assets/logo.jpg` had never been wired into the application: it sat
outside the Next.js root and nothing imported it. What appeared on screen was a hardcoded
purple square with the letters "SBTF" typed into it.

Now: `apps/web/public/logo.jpg` is served, and `BrandMark`
(`apps/web/src/components/layout/brand-mark.tsx`) renders it in three places — the
dashboard sidebar, the unauthenticated header, and the public verification page. Favicon
metadata was also added; the app previously had none.

Two things a future agent should know:

- The asset is an **opaque JPEG** (no alpha channel, plain white field) and all three slots
  sit on `--color-primary: #271564`. The component therefore presents it on a white plate;
  without that it reads as a white rectangle. If a transparent PNG is ever supplied, the
  plate can be removed from that one component.
- `apps/assets/logo.jpg` is still present as an **unused duplicate**. Left in place
  deliberately — deletion was never authorised.

Unverified: a production `next build` was deliberately skipped while the dev server was
running, because both write to `.next`. Typecheck and lint pass.

---

## 5. Known broken, not yet fixed

1. **Add-staff UI does not exist.** `createStaffUserAction` has zero call sites. Covered by
   the invitation plan.
2. **Three UI strings claim an email was sent when none is.** `users.ts:122`,
   `admin-users/index.ts:151`, `verify-email/page.tsx:24-25`. Re-check once SMTP delivery
   works.
3. **Two Edge Functions are not deployed.** `admin-users` (account provisioning) and
   `renewal-reminders` (scheduled reminders) have no deployment in the live project.
   `ai-decision-support` and `password-recovery` are live.
4. **The Gmail App Password used for SMTP was pasted into chat** and must be rotated. See
   the rotation note below; do not revoke it before the replacement is saved, or recovery
   stops working.

### Password recovery — working since 26 October 2026

The whole chain is verified end to end:

| Step | State |
|---|---|
| `password-recovery` Edge Function | deployed v2, **Verify JWT OFF** |
| SMTP host / port | `smtp.gmail.com:587` (STARTTLS) |
| SMTP username / sender | `sangguniangbayan.mabini.batangas@gmail.com` |
| SMTP sender name | `Sangguniang Bayan` |
| SMTP password | valid 16-character Google App Password, verified against Gmail before saving |
| Auth redirect allow-list | includes `https://sbtf-system.vercel.app/auth/confirm` |
| `/recover` result | `status 200`, no `535`, no function-log error (26 Oct 2026 02:40 UTC) |

How it was diagnosed, for the next time it breaks:

- The browser always shows the generic "request accepted" message, even on failure, by
  design (anti-enumeration). Only the logs reveal the truth.
- `source = 'auth_logs'`, filter `event_message ilike '%/recover%'` — a working request
  ends `"status":200` with no `error`. `535 5.7.8 … BadCredentials` means the password is
  the Gmail account password or a revoked App Password. `504 context deadline exceeded`
  means the SMTP port is unreachable (a typo such as `585` hangs for 10 s).
- `source = 'function_logs'` — commit `0548b28` logs
  `password-recovery: could not send the recovery e-mail` with the underlying message,
  while still returning the generic response.
- Supabase stores only a hash of `smtp_pass`. The Management API returns it masked; a
  changed prefix proves the Password field was actually saved.

**Rotating the exposed App Password** (no downtime): create a second App Password, save it
in Supabase → Authentication → Emails → SMTP Settings → Password, send one test recovery,
then revoke the old one at <https://myaccount.google.com/apppasswords>.

---

## 6. Staff-driven workflow rebuild (Phases 1–3)

Target workflow is described in [`process.md`](./process.md): staff handle every step of an
application, administrators are view-only. Implemented so far:

- **Phase 1** — data model and enforcement. New `ApplicationStage` pipeline column plus
  `application_appointments`, `form_requests` and `document_releases` tables; granular
  staff-only RPCs; triggers that own the timeline, audit log and notifications; RLS so an
  administrator can read but never write the workflow tables. Migrations
  `20260101091500`–`091900`.
- **Phase 2** — staff handling UI. `handling-panel.tsx` drives the pipeline (assign,
  compliance, endorsement, decision, release, appointments); `review-panel.tsx` is now
  document-verification only; the Form Requests console lives at `/staff/form-requests`.
- **Phase 3** — scheduling and notifications. A cross-application appointments view at
  `/staff/appointments`, notification deep-links (application, franchise record, form
  requests, appointments) in the bell dropdown and the notifications page, and the Phase 1
  tables added to the Realtime publication (`20260101092000`).

Realtime subscriptions honour RLS; the tables published for `supabase_realtime` are the
original four plus `application_appointments`, `form_requests` and `document_releases`.

---

## 7. Where to look first

| Working on | Read |
|---|---|
| Staff invitations, email confirmation | [`STAFF-INVITATIONS-PLAN.md`](./STAFF-INVITATIONS-PLAN.md) |
| Email copy and wording | [`STAFF-INVITATION-EMAIL-TEMPLATE.md`](./STAFF-INVITATION-EMAIL-TEMPLATE.md) |
| Admin user management UI | `apps/web/src/app/admin/users/page.tsx`, `apps/web/src/components/users/` |
| Roles, permissions, RPCs | `supabase/migrations/20260101090700_phase0_workflow_rpcs.sql` |
| Row level security | `supabase/migrations/20260101090900_phase0_rls_policies.sql` |

### Conventions worth matching

- Security-definer functions carry an explicit `set search_path` and a
  `revoke all … from public, anon, authenticated` line. Follow both.
- UI copy is plain and factual. Where it currently overstates what the system does, treat
  that as a bug to fix rather than the intended behaviour.
- Comments explain *why* a non-obvious choice was made. Match that density.