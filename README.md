# SBTF-System

Franchising and Tricycle Driver Registration System for the Municipality of Mabini,
Batangas. Next.js console (administrator + staff) on Supabase.

## Before you start

Read these first. They record decisions and current state that are not derivable from the
code, and several of them look like bugs but are deliberate.

| Document | Purpose |
|---|---|
| [`docs/CURRENT-STATE.md`](docs/CURRENT-STATE.md) | Live environment, what is done, what is broken, and **credentials that need rotating** |
| [`docs/STAFF-INVITATIONS-PLAN.md`](docs/STAFF-INVITATIONS-PLAN.md) | The active piece of work: staff invitations and email confirmation, phase by phase |
| [`docs/STAFF-INVITATION-EMAIL-TEMPLATE.md`](docs/STAFF-INVITATION-EMAIL-TEMPLATE.md) | Bilingual email copy, awaiting review |

## Commands

Run from the repository root:

```bash
npm run web:dev        # start the app on http://localhost:3000
npm run db:check       # verify Supabase connectivity, table presence, RLS
npm run validate:sql   # parse every migration without applying it
npm run test:rls       # RLS behaviour checks
npm run web:build      # production build
```

`npm run db:check` is the fastest way to confirm the environment is healthy.

## Layout

```
apps/web/          Next.js console — administrator and staff consoles
apps/assets/       Shared source assets (note: the logo here is an unused duplicate)
supabase/
  migrations/      13 applied migrations; extend rather than edit
  functions/       Edge Functions (admin-users, ai-decision-support, renewal-reminders)
  seed.sql         Sample data — deliberately NEVER applied to any environment
scripts/           db-check.mjs
docs/              Plans and current state
```

## Things that will mislead you

- **`supabase/config.toml` applies to local development only.** Per its own header it is
  consumed by `supabase start` and `functions serve`. The cloud project has its own
  settings, including an empty `uri_allow_list` that this file does not reflect.
- **No auth token route exists.** Nothing calls `exchangeCodeForSession` or `verifyOtp`,
  so every Supabase auth link dead-ends.
- **Some UI text promises emails that are never sent.** Treat as bugs.
- **`seed.sql` has never been run.** Do not apply it without asking.