# Current State — Environment and Recent Work

Companion to [`STAFF-INVITATIONS-PLAN.md`](./STAFF-INVITATIONS-PLAN.md). This file records
what has **already been completed**, so the next person does not redo it or assume the
database is empty.

**Last updated:** 2026-10-05

---

## 1. Live environment

| Item | Value |
|---|---|
| Supabase project ref | `qdtmzgaxktebyhsxrgvf` |
| URL | `https://qdtmzgaxktebyhsxrgvf.supabase.co` |
| Branch | `arena/01a104aa-sbtf-system` |
| Local app | `npm run web:dev` → `http://localhost:3000` |
| Connectivity check | `npm run db:check` (script at `scripts/db-check.mjs`) |

`apps/web/.env.local` has `NEXT_PUBLIC_DEMO_MODE=false`, so the app runs against the real
project with real authentication. Demo mode is off **deliberately** — it must never be
enabled outside local UI review, since it disables all writes.

### ⚠️ Exposed credentials — rotate these

These were pasted into chat and must be rotated once the invitation work is done:

- Supabase **personal access token** (platform admin scope)
- **Database password**

Neither is committed to the repository, but both are compromised by exposure. Treat
rotation as a required follow-up task, not optional.

The two account passwords (`admin-password`, `staff-password`) are also weak and were
user-supplied. They should be rotated via the account page.

---

## 2. Database

- **All 13 migrations applied** to the live project and matching remote history.
- 15 tables, 28 public RLS policies, 50 functions, 2 storage buckets.
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

Do not mistake these for configuration problems:

1. **Add-staff UI does not exist.** `createStaffUserAction` has zero call sites. Covered by
   the invitation plan.
2. **No auth-token route exists.** No `exchangeCodeForSession` or `verifyOtp` anywhere, so
   confirmation, recovery, and invitation links all dead-end. Covered by the invitation plan.
3. **Three UI strings claim an email was sent when none is.** `users.ts:122`,
   `admin-users/index.ts:151`, `verify-email/page.tsx:24-25`.
4. **No Edge Functions are deployed.** Calling `supabase.functions.invoke("admin-users")`
   fails immediately.
5. **No SMTP is configured** on the project, and `uri_allow_list` is empty on the cloud
   project. `supabase/config.toml` is local-only and does not apply to the cloud project.

---

## 6. Where to look first

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