# Deployment Guide

How the SBTF System goes from this repository to a working deployment.

**Last updated:** 2026-10-13 · applies to migrations `20260101090000` … `20260101091300` (20 files).

The short version: apply the schema (§2), deploy the Edge Functions (§3), deploy the
web app with two environment variables (§4), then create the first accounts (§5, §6).
Diagnosis commands are in §8.

---

## 1. How the deployed web app connects to Supabase

There is no custom API layer. The Next.js console talks to Supabase directly:

| Concern | Mechanism |
|---|---|
| Data (PostgREST) | `NEXT_PUBLIC_SUPABASE_URL` + publishable key, from the browser and from server components |
| Auth | Supabase Auth, session kept in an httpOnly cookie by `@supabase/ssr` |
| Authorisation | Row Level Security in PostgreSQL. The web app carries no service-role key |
| Privileged operations | Edge Functions only (`admin-users`, `ai-decision-support`, `renewal-reminders`) |
| Files | Private storage buckets `franchise-documents` and `certificates`, signed URLs only |

Consequence: the deployed app is only as configured as its environment variables, and
the two `NEXT_PUBLIC_*` values are the **only** Supabase credentials it ever sees.

---

## 2. Database

### 2.1 Prerequisites

1. A Supabase project (any region; the municipality's data should stay in a region
   acceptable under RA 10173).
2. Either the Supabase CLI logged in (`supabase link`) **or** access to the SQL Editor
   in the dashboard. Both routes are supported; pick one.

### 2.2 Applying the migrations

`supabase/migrations/` contains 26 files, `20260101090000_phase0_types.sql` through
`20260101092500_ai_briefings.sql`. They create the 19 tables,
the public RPC surface (35 functions), RLS policies, storage buckets, Realtime
publication and the scheduled job.

> **Already migrated earlier?** Projects that ran the Phase 0 migrations first need
> the Phase 1 files, `20260101091500_phase1_workflow_types.sql` through
> `20260101091900_phase1_rls_policies.sql` (form requests, appointments/hearings,
> document release and the staff processing pipeline). They are idempotent;
> re-running them changes nothing.

Two supported routes:

**A. Supabase CLI (preferred).** Records migration history so future migrations apply
cleanly:

```bash
supabase link --project-ref <project-ref>
supabase db push
```

**B. SQL Editor (no CLI).** Generate one paste-ready transaction and run it in
Dashboard → SQL Editor:

```bash
npm run db:bundle        # writes supabase/setup-all.sql
npm run db:bundle:seed   # same plus the demonstration dataset (development only)
```

The bundle is one transaction — it either completes or the database is untouched — and
it ends with a verification block that refuses to commit unless at least 15 tables and
exactly 34 barangays are present. After pasting via the SQL Editor, reload the schema
cache (Database → API) so PostgREST sees the new functions.

Both routes are idempotent: re-running them never duplicates anything.

### 2.3 The first administrator account

A fresh project has the schema and no account. Run `supabase/first_admin.sql` once in
the SQL Editor after editing its configuration block (e-mail, temporary password,
name). It writes `auth.users`, the identity row and the profile in one transaction,
with `role = 'administrator'` in `raw_app_meta_data`, and ends with a verification
query that must read `auth_linked = true`, `password_set = true`,
`identity_present = true`. Sign in, then change the password immediately.

---

## 3. Edge Functions

Four functions live in `supabase/functions/`. `admin-users` is required for account
management; deploy `password-recovery` if self-service password recovery is used;
deploy `ai-decision-support` to enable the AI advisory screens; `renewal-reminders` is
only needed when the scheduled reminder job runs.

```bash
# Preferred: sets SITE_URL / ALLOWED_WEB_ORIGINS first, then deploys admin-users.
# SITE_URL is taken from --site-url, then $SITE_URL, then NEXT_PUBLIC_SITE_URL
# in apps/web/.env.local. Requires SUPABASE_ACCESS_TOKEN (or `supabase login`).
npm run functions:deploy -- --site-url https://sbtf-system.vercel.app

# Every function, with the correct Verify JWT setting for each.
npm run functions:deploy:all -- --site-url https://sbtf-system.vercel.app
```

The script uses `--use-api`, so Docker is not required. The equivalent manual
commands are:

```bash
supabase secrets set SITE_URL=https://sbtf-system.vercel.app \
  ALLOWED_WEB_ORIGINS=https://sbtf-system.vercel.app
supabase functions deploy admin-users --use-api
supabase functions deploy ai-decision-support --use-api
supabase functions deploy password-recovery --use-api --no-verify-jwt  # off (see below)
supabase secrets set GROQ_API_KEY=gsk_...      # only for ai-decision-support
```

A deployed function is not the same as a linked local directory: verify it with
`supabase functions list --project-ref <project-ref>` (the script does this
automatically).

| Function | Purpose | Required secrets |
|---|---|---|
| `admin-users` | Create staff/administrator accounts, deactivate/reactivate, permanently delete accounts, generate password links | `SITE_URL` |
| `password-recovery` | Role-aware self-service recovery behind "Forgot your password?" — sends a 6-digit code (Verify JWT **off**) | none (shares `SITE_URL`) |
| `ai-decision-support` | Advisory analytics through the LLM | `GROQ_API_KEY` |
| `renewal-reminders` | Scheduled 90/60/30-day reminder run | none (uses service role) |

`ALLOWED_WEB_ORIGINS` is shared by every function: it is a comma-separated list of the
browser origins allowed by the CORS helper. Localhost is always allowed; any deployed
origin must be listed or the browser rejects the response. See §3.2.

> **`password-recovery` must run with Verify JWT disabled.** It is reached before
> sign-in, so it cannot present a user JWT. `supabase/config.toml` sets
> `[functions.password-recovery] verify_jwt = false`, but that file is **local-only** —
> confirm the toggle is off in Dashboard → Edge Functions → `password-recovery`, or
> deploy with `supabase functions deploy password-recovery --no-verify-jwt`. A 401 here
> is reported in the UI as "the recovery service did not answer (HTTP 401)".

### `SITE_URL`

`admin-users` builds setup/reset links as `${SITE_URL}/auth/confirm?token_hash=…&type=…`.
Set `SITE_URL` as a function secret to the origin being used (production:
`https://sbtf-system.vercel.app`; local testing against the hosted project:
`http://localhost:3000`). It falls back to `http://localhost:3000`.

`password-recovery` no longer returns or e-mails a link, so it no longer needs
`SITE_URL` for that purpose; keep the secret set anyway, since both functions share the
same environment.

The web app's `NEXT_PUBLIC_SITE_URL` is a **separate** value with the same shape — set
both, and keep them on the same origin. Mixing them is the most common cause of a
setup link that lands on the wrong host.

---

## 3.1 Email (SMTP + templates)

Self-service recovery and driver one-time passwords send real e-mail through
Supabase Auth. This is configured **per project in the dashboard** — `config.toml`
only affects local development, where mail is captured by Inbucket.

The deployment here uses a **Gmail account with a Google App Password** (no
transactional provider, no municipal mail server).

### a. SMTP

Dashboard → **Authentication → Emails → SMTP Settings**:

| Field | Value |
|---|---|
| Host | `smtp.gmail.com` |
| Port | `587` (STARTTLS) — `465` also works (SSL) |
| Username | `sangguniangbayan.mabini.batangas@gmail.com` |
| Password | a 16-character **Google App Password** (not the account password) |
| Sender name | e.g. `SBTF System` |
| Sender email | the same Gmail address |

The Gmail account must have 2-Step Verification enabled to generate an App Password
(Google account → Security → App passwords). Use **Send test email** to confirm
delivery to a real mailbox before relying on it.

Two failures are easy to confuse:

- **`535 5.7.8 Username and Password not accepted … BadCredentials`** — the stored
  password is the Gmail account password or a revoked App Password. Generate a fresh
  App Password and paste the 16 characters without spaces. Confirm the username is the
  full Gmail address, not the sender name.
- **`context deadline exceeded` / HTTP 504 on `/recover`** — GoTrue cannot reach the
  SMTP server. Check the port (`587` or `465`; a typo such as `585` hangs until the
  10-second timeout).

The `password-recovery` function keeps its response generic, so the browser cannot show
these errors. It writes them to the function logs instead (Dashboard → Edge Functions →
`password-recovery` → Logs); the same detail appears in Auth logs as `/recover`.

Supabase only stores a hash of the SMTP password, so the dashboard cannot show whether the
saved value is the one you think it is. To test a credential before saving it, run an
`AUTH LOGIN` handshake against `smtp.gmail.com:587` (connect, `EHLO`, `STARTTLS`, upgrade
to TLS, `EHLO`, `AUTH LOGIN`) and confirm `235 2.7.0 Accepted`. A correct password fails
with `535`. A working recovery request ends `"status":200` in the Auth logs with no
`error` field, and produces no `could not send the recovery e-mail` line in the function
logs.

### b. URL configuration (the redirect allow-list)

Dashboard → **Authentication → URL Configuration**:

- **Site URL** — the current environment: `https://sbtf-system.vercel.app` in
  production, `http://localhost:3000` while testing locally against the hosted project.
  **No trailing slash.** Invitation and administrator-issued reset links are built from
  `SITE_URL` (`{{ .SiteURL }}/auth/confirm`), so a stored value ending in `/` produces
  `//auth/confirm`.
- **Redirect URLs** — add both:
  - `https://sbtf-system.vercel.app/auth/confirm`
  - `http://localhost:3000/auth/confirm`

If `/auth/confirm` is not on this list, Supabase silently redirects the administrator's
setup link back to the Site URL and the token is never consumed. Self-service recovery no
longer depends on this list, because it mails a code instead of a link.

### c. Email templates

Three things send mail or links out of this project, and they no longer share a mechanism:

| Purpose | Template | What the user receives |
|---|---|---|
| Self-service password recovery | `supabase/templates/recovery.html` | a **6-digit code**, typed into `/verify-otp` |
| Mobile sign-in | `supabase/templates/magic_link.html` | a 6-digit code, typed into the mobile app |
| Mobile registration | `supabase/templates/confirmation.html` | a 6-digit code; entering it confirms the address **and signs the driver in** |
| Staff invitation | `supabase/templates/invite.html` | an invitation link e-mailed by `create_staff` via `inviteUserByEmail()`, landing on `/accept-invitation` after `/auth/confirm` verifies the token |

The recovery and registration messages deliberately contain **no link**. A single-use
link can be consumed before the human sees it — mail gateways and antivirus scanners
pre-fetch URLs — and it also reintroduces redirect-host and URL-fragment failure modes. A
code cannot be pre-fetched and must be typed by the person holding the mailbox.

The staff invitation is the deliberate exception: it must carry a link because it is the
first sign-in. It uses the token hash against `/auth/confirm`, which verifies server-side
and never exposes the session in a URL fragment.

For **local development** the templates are wired in `supabase/config.toml`:

```toml
[auth.email.template.recovery]
content_path = "./supabase/templates/recovery.html"

[auth.email.template.magic_link]
content_path = "./supabase/templates/magic_link.html"

[auth.email.template.confirmation]
content_path = "./supabase/templates/confirmation.html"

[auth.email.template.invite]
content_path = "./supabase/templates/invite.html"
```

For the **hosted project**, paste the same HTML into Dashboard → **Authentication →
Email Templates**:

| Template | Source file | Subject |
|---|---|---|
| Reset Password | `supabase/templates/recovery.html` | `Your SBTF verification code — SBTF System` |
| Magic Link | `supabase/templates/magic_link.html` | `One-time password — SBTF System` |
| Invite user | `supabase/templates/invite.html` | `SBTF staff account invitation — SBTF System` |
| Confirm signup | `supabase/templates/confirmation.html` | `Confirm your SBTF account — verification code` |

**The files in `supabase/templates/` do nothing on their own.** `supabase/config.toml`
only configures `supabase start` locally; the hosted project keeps its own copies.

Check what the project actually holds (Management API, `/v1/projects/{ref}/config/auth`):

| Key | Value |
|---|---|
| `mailer_templates_recovery_content` | contains `{{ .Token }}`; contains **no** `ConfirmationURL` or `TokenHash` |
| `mailer_templates_confirmation_content` | contains `{{ .Token }}`; contains **no** `ConfirmationURL` or `TokenHash` |
| `mailer_subjects_recovery` | `Your SBTF verification code — SBTF System` |
| `mailer_otp_length` | `6` — must match `otp_length` in `config.toml` |
| `mailer_otp_exp` | `600` seconds — must match `otp_expiry` |
| `site_url` | the production origin, **without** a trailing slash |
| `mailer_templates_magic_link_content` | `{{ .Token }}` |
| `mailer_templates_invite_content` | contains `{{ .TokenHash }}` and `/auth/confirm`; contains **no** `ConfirmationURL` |
| `mailer_subjects_invite` | `SBTF staff account invitation — SBTF System` |

The code is single-use, so a second `POST /verify` with the same digits answers
`403 "One-time token not found"`. That is reuse, not an early expiry. An expired code
fails on the **first** attempt too.

History, because it explains two dead ends that are easy to reintroduce:

- Supabase's default `{{ .ConfirmationURL }}` goes through GoTrue `/verify` and signs the
  visitor in with the **implicit** flow, returning tokens in the URL **fragment**
  (`#access_token=…`) that never reaches the server. `/auth/confirm` then finds neither
  `code` nor `token_hash` and redirects to `/auth/confirmed?status=invalid`.
- With a correct link, `/auth/confirm` used to redirect to `SITE_URL`, which falls back to
  `http://localhost:3000` when `NEXT_PUBLIC_SITE_URL` is missing from the build — so a
  verified production link landed on the developer machine, where the new session cookie
  does not exist. Both auth redirects now derive the origin from the incoming request.

Neither applies to the code flow, but keep them in mind if a link is ever reintroduced.

### d. Staff invitations

`create_staff` now sends the invitation itself with `inviteUserByEmail()`. The template
uses `{{ .TokenHash }}` against `/auth/confirm`, so Supabase's mailer never puts the
session in a URL fragment. `/auth/confirm` verifies the token and forwards the visitor to
`/accept-invitation`, where they choose a password and are sent to `/login`.

The account is still created as `pending`. The invitation can be opened and a password set
immediately, but the console stays closed until an administrator approves the account from
the Users screen.

The function secret `SITE_URL` is used as the `redirectTo` value. The hosted
`site_url` must also be the production origin because the template builds its link from
`.SiteURL`; `config.toml` only affects local development.

`send_password_reset` is no longer offered on the Users screen. The only caller left is
the account owner's own **Account settings → Reset password**, which still receives a
`reset_link` for manual use. Self-service recovery and driver OTP send codes. Do not add
copy that claims mail was sent on a path that only returns a link.

---

## 3.2 AI decision support (Groq)

The AI screens (`/admin/ai-support` and `/staff/ai-support`) produce an advisory briefing
from **aggregated, anonymised** statistics. The system uses **Groq**, not xAI Grok: the
Edge Function calls `https://api.groq.com/openai/v1/chat/completions` with the model named
in `system_settings.ai_model` (default `openai/gpt-oss-120b`).

Flow: browser → `ai-decision-support` (caller's JWT) → `rpc_analytics_ai_context(months)`
→ Groq → structured JSON rendered by the panel. The API key never leaves the Edge
Function, and only counts/rates/TODA names/error excerpts are sent — no applicant names,
contacts, plate or engine numbers.

### Deploy

```bash
supabase functions deploy ai-decision-support   # keep Verify JWT ON
supabase secrets set GROQ_API_KEY=gsk_... ALLOWED_WEB_ORIGINS=https://sbtf-system.vercel.app
```

- **`GROQ_API_KEY`** — create one at <https://console.groq.com/keys>. Without it every
  call returns HTTP 503 `ai_not_configured`.
- **`ALLOWED_WEB_ORIGINS`** — must include the deployed origin, otherwise the browser
  blocks the response before the panel can read it (the CORS helper falls back to
  `http://localhost:3000`).
- Keep **Verify JWT ON**. The function validates the Supabase token, resolves the
  caller's profile, and requires an active `staff` or `administrator` role. Drivers get
  HTTP 403 `forbidden`.

### Runtime settings

Administrator → **Settings** (`system_settings`, category `ai`):

| Key | Default | Effect |
|---|---|---|
| `ai_enabled` | `true` | When `false`, every call returns HTTP 503 `ai_disabled` and the UI disables the button. |
| `ai_model` | `openai/gpt-oss-120b` | Groq model ID; must support JSON mode (`response_format`). The Edge Function allows 4 000 completion tokens because reasoning models bill their hidden reasoning against the same budget. |
| `ai_max_requests_per_user_per_day` | `20` | Per-user 24-hour limit. Excess calls are logged as `rejected`. |

Model availability changes over time: Groq retired `llama-3.3-70b-versatile` and some
keys no longer see it at all (`404 model_not_found`). Confirm the configured model is
listed by `GET https://api.groq.com/openai/v1/models` with the project's key before
changing it. Models must return a JSON object; the panel tolerates a missing section but
logs it under `limitations` rather than inventing content.

### Audit trail

Every attempt appends one row to `ai_request_logs` (model, role, latency, token counts,
SHA-256 hashes of prompt/context, aggregate `context_summary`, status/error code). The
table is **append-only** and readable by administrators only. No prompt text and no
personal data are stored.

### Saved briefings

A briefing costs a model call and several seconds, so the function saves the JSON it
returned in `public.ai_briefings` before answering. Each user has at most one row
(`requester_id` is unique): generating a new briefing replaces it immediately.

- The row carries `expires_at`, set to 24 hours after generation. The page only loads a
  saved briefing while it is inside that window, so after a day the panel starts empty
  again until someone generates a new one.
- The page fetches the saved row on the server and passes it to the panel, which renders
  it unchanged after a refresh, a new sign-in or on another device.
- RLS exposes a row only to its owner (`requester_id = current_profile_id()`). Writes come
  from the Edge Function with the service role, so the table has **no** insert, update or
  delete policy. The `payload` column holds the advisory text and aggregate statistics
  only — no applicant records.
- Saving is best-effort: if the upsert fails, the function logs the error and still
  returns the advisory.

Deploying the function requires the table to exist: apply
`20260101092500_ai_briefings.sql` first.

### Troubleshooting

| Symptom | Cause |
|---|---|
| 503 `ai_not_configured` | `GROQ_API_KEY` is not set for the project. |
| 503 `ai_disabled` | `ai_enabled` is `false` in Settings. |
| 429 `rate_limit_exceeded` | The per-user daily limit was reached; raise the setting or wait 24 h. |
| 403 `forbidden` | Caller is a driver or has no active staff/administrator profile. |
| 500 `context_unavailable` | `rpc_analytics_ai_context` failed — usually a missing Phase 0 migration. |
| Browser CORS error or generic "non-2xx" | Origin missing from `ALLOWED_WEB_ORIGINS`, or the function is not deployed. |

> The Edge Function must call the RPC with the **caller's** JWT, not the service-role
> key: `rpc_analytics_ai_context` is `SECURITY DEFINER` but still gates on
> `is_staff_or_admin()`, which reads `auth.uid()` and is null for service-role requests.

---

## 4. Web application (Vercel)

### 4.1 Environment variables

| Variable | Value | Notes |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://<ref>.supabase.co` | Project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` (or `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`) | publishable key | Both names are accepted; never the service-role key |
| `NEXT_PUBLIC_SITE_URL` | production URL | Used for certificate QR links; auth redirects now follow the request origin instead, so a missing value no longer breaks the reset flow |
| `NEXT_PUBLIC_VERIFICATION_BASE_URL` | optional public URL | Certificate QR address when certificates are generated from a different host (for example, locally). A `localhost` value in the `certificate_verification_base_url` setting is ignored in favour of this, `NEXT_PUBLIC_SITE_URL`, or the request origin. |
| `NEXT_PUBLIC_DEMO_MODE` | unset | Must be absent or `false` in production |

### 4.2 Conditions for sign-in to work on Vercel

Checklist, in the order things actually break:

1. **`NEXT_PUBLIC_*` values are inlined at build time.** Vercel bakes them into the
   JavaScript bundle during `next build`. Setting them *after* a deployment does
   nothing until the next build — redeploy after any change.
2. `NEXT_PUBLIC_DEMO_MODE` is not `"true"`. The check is strict: only the exact
   string `true` enables preview mode, but a stale `true` from a preview deployment
   silently serves sample data with every write disabled.
3. `NEXT_PUBLIC_SITE_URL` matches the real hostname. Since `apps/web/src/lib/env.ts`
   falls back to `http://localhost:3000`, an unset value in a production build used to
   send `/auth/confirm` and the document route to the developer machine after a successful
   token check — the visitor saw a dead link while the session cookie sat unused on the
   Vercel host. Both routes now derive the origin from the incoming request, so the
   redirect stays on the host that served the link; still set the variable, because the
   QR-code path reads it.
4. The Edge Functions are deployed (§3) — `admin-users` for account creation and
   in-console resets, and `password-recovery` (Verify JWT **off**) for the "Forgot your
   password?" screen. A missing `password-recovery` surfaces as "the recovery service
   did not answer (HTTP 404)".
5. Migrations are applied (§2.2). An unmigrated database now produces a
   `/setup-required` page explaining exactly this, instead of a sign-in loop.

If sign-in misbehaves, run `npm run db:check` (§8) before touching code: it stops at
the first broken link in the chain.

---

## 5. Creating staff and administrator accounts

From the console: **Administrator → Users and roles → Create account**.

1. Enter first name, last name, official e-mail, contact number, role
   (`staff` or `administrator`).
2. The `admin-users` Edge Function creates the auth user with the role in
   `raw_app_meta_data` (service role only — clients cannot write it) and sends the
   invitation with `inviteUserByEmail()`.
3. The new user receives the e-mail from the project's SMTP and opens
   `/accept-invitation` to choose a password. The dialog reports that the invitation was
   sent; nothing has to be copied by hand.
4. The account is created as **Awaiting approval**. Approve it from the Users screen; the
   new staff member can then sign in with the password they set. If the e-mail is lost,
   they can use **Forgot your password?** on `/login` once the account is approved.

Self-registration is deliberately driver-only (mobile app); there is no public sign-up
for staff roles.

---

## 6. Demonstration dataset (development only)

`supabase/seed.sql` creates synthetic accounts and records — 1 administrator,
3 staff, 72 drivers (three per TODA), applications across every status, and franchise
records. It contains **no real personal data** and must never run against the
production project.

| Role | E-mail pattern | Password |
|---|---|---|
| administrator | `admin@mabini-sbtf.test` | `Admin@Mabini2026` |
| staff | `staff1…staff3@mabini-sbtf.test` | `Staff@Mabini2026` |
| driver | `driverNNN@mabini-sbtf.test` | `Driver@Mabini2026` |

Loading it: paste the whole file into the SQL Editor (or `npm run db:bundle:seed` and
paste the bundle). It is additive and idempotent — re-running skips accounts that
already exist (matched on e-mail) and never touches accounts outside
`@mabini-sbtf.test`. See `docs/testing.md` §3–4 for the traps this data sets for
testers.

---

## 7. Mobile application

The Flutter app ships configuration at build time; see `docs/mobile.md` §5. Only the
publishable key is embedded, which is safe because RLS is the authorisation boundary.

---

## 8. Diagnosis commands

| Command | What it proves | Needs a database |
|---|---|---|
| `npm run validate:sql` | Every migration, seed and pgTAP statement parses with the real PostgreSQL grammar | No |
| `npm run db:check` | 8-step read-only diagnosis: env, reachability, key acceptance, 19 tables, 35 functions, buckets, optional sign-in, RLS probe. Stops at the first broken link | Yes |
| `npm run db:verify` | Replays the console's actual queries against the live project and compares response shapes with the TypeScript interfaces | Yes |
| `npm run test:verify` | Self-test of the verifier against a local mock — proves the guard works, no database | No |
| `npm run test:rls` | pgTAP suites (requires Supabase CLI + a project) | Yes |

`db:check` and `db:verify` print key suffixes only, never whole keys.

---

## 9. Honest caveats

- **Not executed end-to-end in CI.** CI validates SQL statically (`validate:sql`) and
  self-tests the live verifier against a mock (`test:verify`). Applying migrations and
  running the pgTAP suites still requires a Supabase project; those steps were last run
  by hand, and the results belong in `docs/CURRENT-STATE.md`.
- **SMTP is configured for self-service recovery and driver sign-in only.** Recovery
  sends a 6-digit code and driver sign-in sends a one-time password; both are delivered
  through the project's Gmail SMTP (§3.1). Staff *invitations* still hand over a link in
  the console (§3.1d), because the account is `pending` until an administrator approves
  it. This is deliberate, not a bug.
- The scheduled renewal job (`rpc_generate_renewal_reminders`) needs a pg_cron /
  scheduled-job registration on the project; the migration declares the function but
  registration on a brand-new project should be confirmed after deploy.
