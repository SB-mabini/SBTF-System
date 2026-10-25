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

### 2.2 Applying the 20 migrations

`supabase/migrations/` contains 20 files, `20260101090000_phase0_types.sql` through
`20260101091900_phase1_rls_policies.sql`. They create the 18 tables,
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
supabase functions deploy admin-users
supabase functions deploy ai-decision-support
supabase functions deploy password-recovery    # keep Verify JWT OFF (see below)
supabase secrets set SITE_URL=https://sbtf-system.vercel.app
supabase secrets set ALLOWED_WEB_ORIGINS=https://sbtf-system.vercel.app
supabase secrets set GROQ_API_KEY=gsk_...      # only for ai-decision-support
```

| Function | Purpose | Required secrets |
|---|---|---|
| `admin-users` | Create staff/administrator accounts, deactivate/reactivate, generate password links | `SITE_URL` |
| `password-recovery` | Role-aware self-service recovery behind "Forgot your password?" (Verify JWT **off**) | `SITE_URL` |
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

Both functions build links as `${SITE_URL}/auth/confirm?token_hash=…&type=…`. Set
`SITE_URL` as a function secret to the origin being used (production:
`https://sbtf-system.vercel.app`; local testing against the hosted project:
`http://localhost:3000`). It falls back to `http://localhost:3000`.

The web app's `NEXT_PUBLIC_SITE_URL` is a **separate** value with the same shape — set
both, and keep them on the same origin. Mixing them is the most common cause of a
recovery link that lands on the wrong host.

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

### b. URL configuration (the redirect allow-list)

Dashboard → **Authentication → URL Configuration**:

- **Site URL** — the current environment: `https://sbtf-system.vercel.app` in
  production, `http://localhost:3000` while testing locally against the hosted project.
- **Redirect URLs** — add both:
  - `https://sbtf-system.vercel.app/auth/confirm`
  - `http://localhost:3000/auth/confirm`

If `/auth/confirm` is not on this list, Supabase silently redirects the e-mail link
back to the Site URL and the token is never consumed.

### c. Email templates

The `{{ .ConfirmationURL }}` in the default templates returns a PKCE `?code=` that the
app cannot exchange, because recovery is requested **server-side** (no browser
`code_verifier` exists). The templates therefore build the link from `{{ .TokenHash }}`
and point at the app's own `/auth/confirm` route, which verifies it with `verifyOtp()`.

For **local development** the templates are wired in `supabase/config.toml`:

```toml
[auth.email.template.recovery]
content_path = "./supabase/templates/recovery.html"

[auth.email.template.magic_link]
content_path = "./supabase/templates/magic_link.html"
```

For the **hosted project**, paste the same HTML into Dashboard → **Authentication →
Email Templates**:

| Template | Source file | Subject |
|---|---|---|
| Reset Password | `supabase/templates/recovery.html` | `Pag-reset ng password — SBTF System \| Reset your password — SBTF System` |
| Magic Link | `supabase/templates/magic_link.html` | `One-time password — SBTF System` |

The Magic Link template **must contain `{{ .Token }}`** — the mobile app signs in by
typing the 6-digit code. Keep `otp_length = 6` in the dashboard to match
`config.toml`.

### d. What still hands over a link

`create_staff` still **returns** the setup link (`setup_link`) instead of e-mailing it,
because a new staff account is `pending` and unusable until an administrator approves
it — e-mailing a single-use link at creation time would let it expire before the
account could be used. The console shows the link for manual handover. Self-service
recovery (`password-recovery`) and driver OTP do send e-mail. Do not add copy that
claims mail was sent on a path that only returns a link.

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
| `NEXT_PUBLIC_SITE_URL` | production URL | Used for auth redirects and certificate QR links |
| `NEXT_PUBLIC_DEMO_MODE` | unset | Must be absent or `false` in production |

### 4.2 Conditions for sign-in to work on Vercel

Checklist, in the order things actually break:

1. **`NEXT_PUBLIC_*` values are inlined at build time.** Vercel bakes them into the
   JavaScript bundle during `next build`. Setting them *after* a deployment does
   nothing until the next build — redeploy after any change.
2. `NEXT_PUBLIC_DEMO_MODE` is not `"true"`. The check is strict: only the exact
   string `true` enables preview mode, but a stale `true` from a preview deployment
   silently serves sample data with every write disabled.
3. `NEXT_PUBLIC_SITE_URL` matches the real hostname, or recovery links redirect to the
   wrong origin.
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
   `raw_app_meta_data` (service role only — clients cannot write it) and returns a
   password-setup link.
3. The dialog shows the link in a read-only field with a copy button. **No e-mail is
   sent.** Pass the link to the new user yourself.
4. The link is single-use and expires. If it is lost, **Send password reset** on the
   user's row generates a new one the same way.

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
| `npm run db:check` | 8-step read-only diagnosis: env, reachability, key acceptance, 18 tables, 35 functions, buckets, optional sign-in, RLS probe. Stops at the first broken link | Yes |
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
- **SMTP is configured for self-service recovery only.** Password-recovery and driver
  one-time-password e-mails are delivered through the project's Gmail SMTP (§3.1).
  Staff *invitations* still hand over a link in the console (§3.1d), because the account
  is `pending` until an administrator approves it. This is deliberate, not a bug.
- The scheduled renewal job (`rpc_generate_renewal_reminders`) needs a pg_cron /
  scheduled-job registration on the project; the migration declares the function but
  registration on a brand-new project should be confirmed after deploy.
