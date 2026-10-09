# SBTF-System

Franchising and Tricycle Driver Registration System for the Municipality of Mabini,
Batangas. Next.js console (administrator + staff) and Flutter driver app on Supabase.

## Before you start

Read these first. They record decisions and current state that are not derivable from the
code, and several of them look like bugs but are deliberate.

| Document | Purpose |
|---|---|
| [`docs/CURRENT-STATE.md`](docs/CURRENT-STATE.md) | Live environment, what is done, what is broken, and **credentials that need rotating** |
| [`docs/deployment.md`](docs/deployment.md) | Migrations, Edge Functions, Vercel sign-in conditions, first-admin bootstrap, diagnosis commands |
| [`docs/testing.md`](docs/testing.md) | Phase 1–2 acceptance plan (admin A-01…A-17, staff S-01…S-17, security X-01…X-08), seed-data traps, cross-check SQL |
| [`docs/mobile.md`](docs/mobile.md) | Phase 3 mobile app: implemented slices 1–2, session-guard decision table, acceptance cases MA-01…MA-14, roadmap |
| [`docs/STAFF-INVITATIONS-PLAN.md`](docs/STAFF-INVITATIONS-PLAN.md) | Historical design notes on staff invitations and email confirmation |
| [`docs/STAFF-INVITATION-EMAIL-TEMPLATE.md`](docs/STAFF-INVITATION-EMAIL-TEMPLATE.md) | Bilingual email copy, awaiting review |

## Requirements

- **Node ≥ 20** for local web work (engines pinned in `package.json`).
- Supabase CLI optional but recommended (`supabase link` / `db push`); the SQL Editor
  route is documented as a fallback.
- Flutter 3.x stable only for `apps/mobile` (see `docs/mobile.md`).

## Commands

Run from the repository root:

```bash
npm run web:dev        # start the app on http://localhost:3000
npm run validate:sql   # parse every migration with the real PostgreSQL grammar
npm run db:check       # 8-step read-only diagnosis of a live project
npm run db:verify      # replay the console's queries against the live schema
npm run test:verify    # self-test of the verifier (mock Supabase, no database)
npm run db:bundle      # concatenate the 14 migrations into one paste-ready file
npm run test:rls       # pgTAP suites (needs Supabase CLI + a project)
npm run web:build      # production build
```

`npm run db:check` is the fastest way to confirm an environment is healthy;
`npm run test:verify` runs in CI and needs nothing installed beyond npm.

## Layout

```
apps/web/          Next.js console — administrator and staff consoles
apps/mobile/       Flutter driver/operator app (Phase 3, slices 1–2)
apps/assets/       Shared source assets (note: the logo here is an unused duplicate)
supabase/
  migrations/      14 applied migrations; extend rather than edit
  functions/       Edge Functions (admin-users, ai-decision-support, renewal-reminders)
  seed.sql         Sample data — development only, see docs/testing.md §3
  first_admin.sql  Idempotent first-administrator bootstrap for fresh projects
scripts/           validate-sql, check-supabase, verify-live, bundle-sql, …
docs/              Deployment, testing and mobile documentation
```

## Things that will mislead you

- **`supabase/config.toml` applies to local development only.** Per its own header it is
  consumed by `supabase start` and `functions serve`. The cloud project has its own
  settings, including an empty `uri_allow_list` that this file does not reflect.
- **No e-mail is sent for invitations or password resets — by design.** The
  `admin-users` Edge Function returns the link (`setup_link` / `reset_link`) and the
  console shows it for manual handover. Supabase's built-in mailer is rate-limited
  without SMTP and would silently drop municipal addresses. See `docs/deployment.md` §3.
- **Recovery/setup links work when opened** — `supabase-js` picks the token up from the
  URL on `/reset-password`. What has no consumer yet is a dedicated `/auth/callback`
  route for other flows; sign-in from a link always lands on the reset-password page.
- **`seed.sql` has never been applied to production.** Do not apply it there. It is
  additive and idempotent in development; see `docs/testing.md` §3–4 for the traps it
  sets for testers.
