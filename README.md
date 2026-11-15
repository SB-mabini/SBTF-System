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
| [`docs/mobile.md`](docs/mobile.md) | Phase 3 mobile app: implemented slices, session-guard decision table, install page, release process, acceptance cases MA-01…MA-56, roadmap |
| [`docs/STAFF-INVITATIONS-PLAN.md`](docs/STAFF-INVITATIONS-PLAN.md) | Historical design notes on staff invitations and email confirmation |
| [`docs/STAFF-INVITATION-EMAIL-TEMPLATE.md`](docs/STAFF-INVITATION-EMAIL-TEMPLATE.md) | Bilingual email copy, awaiting review |

## Requirements

- **Node ≥ 20** for local web work (engines pinned in `package.json`).
- Supabase CLI optional but recommended (`supabase link` / `db push`); the SQL Editor
  route is documented as a fallback.
- Flutter 3.x stable only for `apps/mobile` (see `docs/mobile.md`).

## Live URLs

| What | Who uses it | URL |
|---|---|---|
| Console (sign-in) | Administrators, staff | <https://sbtf-system.vercel.app> |
| Driver install page | Drivers, operators | <https://sbtf-application.vercel.app/install/> |
| Printable poster (A4) | Barangay and TODA notice boards | <https://sbtf-application.vercel.app/install/poster.html> |
| Release manifest | The app's in-app update check | <https://sbtf-application.vercel.app/install/release.json> |
| APK downloads | GitHub Releases (binaries are not in git) | <https://github.com/SB-mabini/SBTF-System/releases> |
| Supabase project | Backend, Edge Functions | <https://supabase.com/dashboard/project/qdtmzgaxktebyhsxrgvf> |

Both Vercel URLs are public on purpose and must stay outside Vercel SSO: drivers and staff
opening an invitation e-mail cannot sign in to Vercel. The install page is plain HTML from
`apps/mobile/web/install/`; it is **not** part of the Next.js console.

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
npm run auth:email     # verify the hosted Auth e-mail templates send codes
npm run auth:email:apply  # push supabase/templates/* to the hosted project
npm run install:publish  # upload split release APKs and update the /install manifest
npm run install:page     # assemble /install (page, QR, APKs) inside build/web
```

A mobile release is cut from a tag: bump `version:` in `apps/mobile/pubspec.yaml`, push it,
then push an `app-v<version>-<build>` tag (for example `app-v0.1.0-4`).
[`.github/workflows/mobile-release.yml`](.github/workflows/mobile-release.yml) builds and
signs the APKs, publishes the GitHub Release, and commits the new
`apps/mobile/web/install/release.json` back to `main`, which makes Vercel rebuild `/install/`.

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
  settings, including an empty `uri_allow_list` that this file does not reflect. E-mail
  templates are copied there too — `npm run auth:email` reports whether the hosted
  project sends 6-digit codes or Supabase's default confirmation link.
- **Self-service recovery e-mails a 6-digit code, not a link.** The visitor types it back into
  `/verify-otp`, then chooses to continue to the console or set a new password. E-mail is also
  used for driver one-time passwords. Mail goes through the project's Gmail SMTP
  (`docs/deployment.md` §3.1).
- **Staff invitations are e-mailed links.** `create_staff` calls `inviteUserByEmail()`; the
  template sends the staff member to `/accept-invitation` to set a password and then to
  `/login`. The account is still `pending` until an administrator approves it. Only
  `send_password_reset` still **returns** a link (`reset_link`), and its only caller is the
  account owner's own Account settings.
- **`/auth/confirm` consumes every auth link.** It handles `?token_hash=…&type=invite|recovery`
  (the invitation template and the `admin-users` reset link) and Supabase's `?code=…` PKCE
  flow, then forwards invites to `/accept-invitation` and recovery to `/reset-password`.
  See `apps/web/src/app/auth/confirm/route.ts`.
- **`seed.sql` has never been applied to production.** Do not apply it there. It is
  additive and idempotent in development; see `docs/testing.md` §3–4 for the traps it
  sets for testers.
