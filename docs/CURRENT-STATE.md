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

The **Google App Password** that was pasted into chat on 26 October 2026 was replaced and
revoked on the same day; the value now stored in the Supabase config was never exposed.
Nothing else needs rotating for SMTP.

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

1. **`renewal-reminders` is not deployed, and does not need to be.** `pg_cron` job 1 runs
   `public.rpc_generate_renewal_reminders(array[90, 60, 30])` daily at 01:15 in-database.
   Deploy the function only if an HTTP entry point is wanted; it also requires the
   `REMINDER_CRON_SECRET` secret, which is not set.

### `admin-users` deployment (redeployed 14 November 2026)

`admin-users` is deployed to project `qdtmzgaxktebyhsxrgvf` (version 8) with
`SITE_URL=https://sbtf-system.vercel.app` and `ALLOWED_WEB_ORIGINS` set. The endpoint
answers HTTP 401 without a user JWT instead of HTTP 404. Redeploy after changing the
function with:

```bash
npm run functions:deploy -- --site-url https://sbtf-system.vercel.app
```

Pass `--site-url` explicitly: without it the script falls back to
`NEXT_PUBLIC_SITE_URL` in `apps/web/.env.local`, which is `http://localhost:3000`.

The script sets the secrets before deploying and uses `--use-api`, so Docker is not
required. The deactivation action now also honours the `suspended` status instead of
always writing `inactive`.

`create_staff` now writes `role = 'staff'` on the profile explicitly, instead of relying
only on the `auth.users` trigger. The trigger falls back to `driver` when it cannot read
the role from `app_metadata`, which produced staff accounts that appeared under Operators.
One account created before this fix (`659ec9e9-33b3-4b01-b61c-9d21606ce45f`) was corrected
to `staff` directly.

### Staff invitations — e-mailed link (changed 13 November 2026)

`create_staff` now calls `inviteUserByEmail()` and lets Supabase Auth send the invitation.
The recipient opens `supabase/templates/invite.html`, which links to
`/auth/confirm?token_hash=…&type=invite`; `/auth/confirm` verifies the token and forwards to
the dedicated `/accept-invitation` panel. The staff member sets a password, is signed out,
and lands on `/login?notice=password-set`.

The account is still created as `pending`. An administrator approves it from the Users
screen before the new staff member can use the console.

The console has no manual-link fallback: if the invitation cannot be sent, creation fails
and rolls the Auth user back rather than handing the administrator a link to copy. The
hosted invite template and `site_url` are applied with
`node scripts/apply-auth-email-config.mjs --apply`; as of 14 November 2026 the hosted
project matches `supabase/templates/invite.html`.

The invitation host comes from the hosted Auth **Site URL**, not from the function
secret: the template builds its link as `{{ .SiteURL }}/auth/confirm`. On 14 November
2026 the stored value was still `https://sbtf-system-sangguniang-bayan-mabini.vercel.app/`
— the legacy Vercel alias, which sits behind Vercel SSO — so every invitation button
landed on `vercel.com/login`. `npm run auth:email` (read-only) now reports that mismatch
and exits non-zero. Run it after any Auth change:

```bash
npm run auth:email            # verify site_url + templates, non-zero on drift
npm run auth:email:apply      # push the repository templates and pinned site_url
```

`create_staff` also recovers from a half-created account left by an earlier version:
when the address is "already registered" but has no profile and the Auth user was
never confirmed or signed in, the stale Auth user is removed and the invitation is
sent once more.

### Permanent account deletion (added 13 November 2026)

The administrator Users screen now has a **Delete account** action on both the Staff and
Operators tabs. It is a true purge, not a deactivation:

- the profile's applications, documents, franchise records, form requests, notifications,
  device tokens, agreements, AI briefings and audit-log entries are deleted;
- files under `{profile_id}/` in `franchise-documents` and `certificates` are removed through
  the Storage API;
- the Supabase Auth user is deleted, so the account can never sign in again;
- the anonymised `toda_members` roster row is kept (only `profile_id` is nulled).

Guard rails:

- only an active administrator can call it;
- your own account and the **last active administrator** are protected;
- an account that acted on **other people's** records (reviewed, verified, issued,
  released, scheduled or endorsed) is refused — deleting it would violate workflow
  consistency checks and rewrite history. Deactivate those accounts instead;
- it does not run in preview/demo mode.

Implementation: `supabase/migrations/20261113000100_user_purged_action.sql` and
`20261113000200_admin_purge_account.sql` add `rpc_admin_collect_account_assets()` and
`rpc_admin_purge_account()`. The `admin-users` Edge Function removes the storage objects and
calls the RPC; the web action is `purgeAccountAction` in `apps/web/src/lib/actions/users.ts`.
Each purge writes one `user_purged` activity entry naming the acting administrator, with no
name or e-mail in its metadata.

> The append-only log triggers would normally block erasure. The RPC disables
> `trg_activity_logs_immutable` and `trg_ai_request_logs_immutable` for its own
> transaction only, then re-enables them. Both migrations must be applied and
> `admin-users` redeployed before the button works.

This feature is deliberately isolated so it can be removed later: drop the two migrations,
the `purge_account` branch in `admin-users/index.ts`, `purgeAccountAction`, and the delete
block in `components/users/user-actions.tsx`.

### Password recovery — e-mail code (changed 4 November 2026)

Recovery no longer sends a link. The visitor receives a **6-digit code**, types it back into
the app, and then chooses whether to continue to the console or set a new password.

| Step | Where | What happens |
|---|---|---|
| 1 | `/forgot-password` | the address is submitted to the `password-recovery` Edge Function |
| 2 | Edge Function | role filter: administrator or **active** staff → send; pending staff → nothing; driver/operator → nothing |
| 3 | Supabase mailer | `supabase/templates/recovery.html` renders `{{ .Token }}`; valid 10 minutes |
| 4 | `/verify-otp` | address kept in an httpOnly cookie; `verifyRecoveryCodeAction` calls `verifyOtp({ type: "recovery" })` |
| 5 | `/recovery-choice` | **Continue to the console** (`/admin` or `/staff`) or **Set a new password** |
| 6 | `/reset-password` | server-guarded; `updateUser({ password })`, then back to the console |

Configuration the hosted project must hold (check it with the Management API, as in
`deployment.md` §3.1c — the repo copy is not what serves production):

| Key | Value |
|---|---|
| `mailer_otp_length` | `6` |
| `mailer_otp_exp` | `600` seconds |
| `mailer_subjects_recovery` | `Your SBTF verification code — SBTF System` |
| `mailer_templates_recovery_content` | `supabase/templates/recovery.html`, contains `{{ .Token }}` and no link |
| `site_url` | `https://sbtf-system.vercel.app` — no trailing slash |

SMTP is unchanged: `smtp.gmail.com:587`, sender
`sangguniangbayan.mabini.batangas@gmail.com`, App Password rotated 26 October — delivery is
proven. The `password-recovery` function must be redeployed for its message to mention a code,
but the flow itself does not depend on that copy.

**Why a code replaced the link.** A single-use link can be consumed before the human sees
it: mail gateways and antivirus scanners pre-fetch URLs. A code cannot be pre-fetched. The
change also removes both link-specific failure modes below from the recovery path.

`/auth/confirm` still exists, and now serves both the staff invitation e-mails sent by
`admin-users` and the recovery links it returns for manual handover. Do not remove it.

#### The three link faults, for context

They are fixed, and the code flow does not touch them, but they explain the history and
will matter if a link is ever reintroduced.

1. **Delivery (`535` / `504`).** The SMTP port was `585` (unreachable → `504 context
   deadline exceeded`) and the username was the sender name instead of the Gmail address.
   Then Gmail answered `535 5.7.8 … BadCredentials` because the stored password was not an
   App Password. Fixed 26 October.
2. **The template.** The hosted project still held Supabase's default, which uses
   `{{ .ConfirmationURL }}`. That goes through GoTrue `/verify`, signs the visitor in with
   the **implicit** flow and returns the tokens in the URL **fragment**
   (`#access_token=…`), which never reaches the server. `/auth/confirm` saw neither `code`
   nor `token_hash` and redirected to `/auth/confirmed?status=invalid`. The repo templates
   had been correct all along; `config.toml` is local-only. Applied 4 November.
3. **The redirect host.** With a correct link, `/auth/confirm` verified the token and then
   redirected to `http://localhost:3000/reset-password`, because `SITE_URL`
   (`apps/web/src/lib/env.ts`) falls back to localhost when `NEXT_PUBLIC_SITE_URL` is
   absent from the build. The cookie lived on the Vercel host, so the form found no
   session; every re-click then answered `403 "One-time token not found"` because the
   token is single-use. Both auth redirects now use `request.nextUrl.origin`.

#### Reading the logs

- `source = 'auth_logs'`, filter `event_message ilike '%/recover%'` — `"status":200` means
  GoTrue accepted the request. `535 … BadCredentials` is a wrong App Password;
  `504 context deadline exceeded` is an unreachable SMTP port.
- `source = 'function_logs'` — commit `0548b28` logs
  `password-recovery: could not send the recovery e-mail` while the browser still sees the
  generic confirmation (anti-enumeration).
- A code flow that works produces a **`POST /verify` issued by the app** answering `200`,
  followed by `/recovery-choice`. `403 "One-time token not found"` after one success means
  the code was reused; an expired code fails on the first attempt too.
- Supabase stores only a hash of `smtp_pass`; a changed prefix proves the Password field
  was really saved. Template and `site_url` values are returned verbatim — read them back
  rather than trusting the repo copy.

#### Verified on 5 November 2026

Applied through the Management API and read back: template with exactly two `{{ .Token }}`
placeholders and no link placeholders, subject, `mailer_otp_length = 6`, `mailer_otp_exp =
600`, `site_url = https://sbtf-system.vercel.app`. `password-recovery` redeployed with Verify
JWT off.

Then, without touching the mailbox:

- `POST /auth/v1/admin/generate_link {type: "recovery"}` returned `email_otp` as **6 digits**.
- `POST /auth/v1/verify {type: "recovery"}` with it answered `200` and an access token.
- The same code again answered `403`; a wrong code answered `403` on the first attempt.
- With the resulting session, `/recovery-choice` rendered its heading, the `/admin` button and
  `/reset-password`; `/reset-password` rendered the form; `/verify-otp` without the pending
  address redirected to `/`; `/recovery-choice` without a session redirected to
  `/forgot-password`.

Not exercised: the actual `updateUser({ password })`. Changing the live administrator's
password just to test it is not acceptable, so the first real password change will be the
first observation of that step. The session is created by `verifyOtp` seconds earlier, which
is what `secure_password_change` requires.

Template note: never put a Go-template placeholder inside an HTML comment. GoTrue renders it
there too, so a `ConfirmationURL` in a comment would put a live recovery link into the message
source — exactly what the code flow exists to avoid.

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