# Deployment Guide

How the SBTF System goes from this repository to a working deployment.

**Last updated:** 2026-10-08 · applies to migrations `20260101090000` … `20260101091300` (14 files).

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

### 2.2 Applying the 14 migrations

`supabase/migrations/` contains 14 files, `20260101090000_phase0_types.sql` through
`20260101091300_phase0_driver_document_replacement.sql`. They create the 15 tables,
the public RPC surface (21 functions), RLS policies, storage buckets, Realtime
publication and the scheduled job.

> **Already migrated earlier?** Projects that ran migrations 1–13 need only the new
> file, `20260101091300_phase0_driver_document_replacement.sql` (the driver
> document-replacement RPC). It is idempotent; re-running it changes nothing.

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

Three functions live in `supabase/functions/`. Deploy at least `admin-users`; the
other two are optional per environment.

```bash
supabase functions deploy admin-users
supabase secrets set SITE_URL=https://your-app.vercel.app
```

| Function | Purpose | Required secrets |
|---|---|---|
| `admin-users` | Create staff/administrator accounts, deactivate/reactivate, generate password links | `SITE_URL` |
| `ai-decision-support` | Advisory analytics through the LLM | `GROQ_API_KEY` |
| `renewal-reminders` | Scheduled 90/60/30-day reminder run | none (uses service role) |

### Why `SITE_URL` matters, and why no e-mail is sent

`admin-users` generates recovery links that redirect to `${SITE_URL}/reset-password`.
`generateLink()` only **creates** the link — it never sends anything. Supabase's
built-in mailer is rate-limited on projects without SMTP and usually delivers only to
addresses already on the project team, so an invitation to a real municipal address
would silently never arrive.

The function therefore **returns the link** (`setup_link` / `reset_link` in the JSON
response) and the console shows it to the administrator, who passes it on through
whatever channel the office actually uses. Do not re-add code that claims an e-mail
was sent unless an SMTP provider is configured and verified.

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
4. The Edge Function `admin-users` is deployed (§3) — otherwise account creation and
   password resets fail loudly with a "deploy admin-users" message rather than
   creating a half account.
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
| `npm run db:check` | 8-step read-only diagnosis: env, reachability, key acceptance, 15 tables, 21 functions, buckets, optional sign-in, RLS probe. Stops at the first broken link | Yes |
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
- **No SMTP is configured.** Any feature that promises e-mail delivery actually hands
  over a link in the console instead (§3). This is deliberate, not a bug.
- The scheduled renewal job (`rpc_generate_renewal_reminders`) needs a pg_cron /
  scheduled-job registration on the project; the migration declares the function but
  registration on a brand-new project should be confirmed after deploy.
