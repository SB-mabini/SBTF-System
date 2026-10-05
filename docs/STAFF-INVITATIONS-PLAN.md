# Staff Invitations & Email Confirmation — Plan and Status

**Status:** design agreed, not yet implemented. No production code has been written.
**Last updated:** 2026-10-05
**Branch at time of writing:** `arena/01a104aa-sbtf-system`

This file is the handover document for the staff-invitation feature. It records what
was decided, why, and exactly what remains. Read it before changing anything in this
area — several decisions here are deliberate and would be easy to undo by accident.

---

## 1. The problem being solved

An administrator needs to add a staff member from the web console. The new person
receives an email, clicks a link, confirms their address, and can then sign in.

The same email mechanism is eventually wanted for driver/operator self-registration,
but **that is explicitly out of scope for this phase** (see §9).

---

## 2. Why the obvious implementation is wrong

Three things in the current code look like they already do this job. They do not, and
each failure mode is easy to mistake for a configuration problem:

| Looks like it works | Reality |
|---|---|
| `createStaffUserAction` in `apps/web/src/lib/actions/users.ts:88` | **Dead code.** Zero call sites anywhere in `src`. Defined, never called. |
| The success message on that action (`users.ts:122`) | Claims "the new user receives a Supabase Auth e-mail". **No email is sent.** |
| `admin-users` Edge Function, `create_staff` action | Calls `generateLink()` and throws the result away. Generating a link is not sending it. |

Three separate UI strings make the same false promise — `users.ts:122`,
`admin-users/index.ts:151`, and `app/(auth)/verify-email/page.tsx:24-25`. Fixing the
messages is part of this work, not an optional extra.

### The deeper blocker: nothing consumes an auth token

`apps/web/src/lib/supabase/middleware.ts:48-50` calls `auth.getUser()` against
**existing cookies only**. There is no `exchangeCodeForSession` and no `verifyOtp`
anywhere in the codebase.

Consequence: **every** Supabase auth link dead-ends. Not just staff invitations —
password recovery and email confirmation are broken the same way, for the same reason.
`reset-password-form.tsx:26` waits on `auth.getUser()` to return a user, but no session
can ever be established from the link, so it hangs at "not ready" forever.

The groundwork is partly pre-wired for this fix and was never finished:

- `supabase/config.toml:52` already whitelists `/auth/confirm` as a redirect target.
- `middleware.ts:13` already treats `/auth` as a public path.

The route was designed. It was simply never built.

---

## 3. Decision: Nodemailer, not Supabase SMTP

Supabase's built-in mailer cannot be used here. Confirmed against the live project:

- `smtp_host` is empty, `external_email_enabled` is true, `mailer_autoconfirm` is false.
- No custom SMTP is configured.
- The free tier is rate-limited well below what driver registration needs.
- A verified sending domain with SPF/DKIM is required, and **no such domain exists yet**.

**Decision:** send mail with Nodemailer from the `admin-users` Edge Function, using a
**dedicated system Gmail account** (not the administrator's personal address).

This side-steps Supabase's mailer completely. Confirmation becomes our own flow, which
means the no-domain constraint stops being fatal.

### The key technique — reuse Supabase's crypto, own the delivery

Do **not** build a custom confirmation-token table. Instead:

1. `generateLink({ type: "verify" })` → read `properties.hashed_token`
2. Email that token inside **our own** template via Nodemailer
3. On click, call `verifyOtp({ type: "email", token_hash })`

This keeps Supabase's single-use, expiring, unforgeable token verification while we
control presentation and delivery. Writing a bespoke token table would mean reimplementing
that security property from scratch.

### Where Nodemailer runs, and why

Nodemailer executes **inside the Edge Function** (`npm:nodemailer@7` works under Deno),
not in the web app. Two reasons:

- The web app deliberately has **no service-role key** (`apps/web/.env.example:19-22`).
  Without it, a server action cannot call `generateLink` at all.
- Token minting and sending must happen in the same place. Splitting them means the
  token has to cross a trust boundary.

---

## 4. Target flow

```
Admin invites staff
  └─ admin-users function (service role)
       ├─ createUser({ email_confirm: false })      ← was true
       ├─ profiles.account_status = 'pending'       ← trigger defaults to 'active'
       ├─ generateLink{type:'verify'} → hashed_token
       └─ Nodemailer → bilingual template

Staff clicks  →  /auth/confirm?token_hash=…
  ├─ verifyOtp{type:'email', token_hash}
  │    └─ GoTrue sets auth.users.email_confirmed_at
  ├─ trg_confirm_pending_account fires
  │    └─ profiles 'pending' → 'active'
  ├─ trg_log_status_change fires (already exists)
  │    ├─ writes activity_logs row
  │    └─ inserts in-app notification
  └─ redirect → /auth/confirmed

Staff signs in at /login
```

---

## 5. Implementation phases

### Phase 1 — Schema

New file `supabase/migrations/20260101091400_pending_account_status.sql`.

```sql
alter type public.account_status add value if not exists 'pending';

comment on type public.account_status is
  'active = may use the system; pending = invited, e-mail not yet confirmed; '
  'inactive = voluntarily disabled; suspended = administratively blocked.';
```

`account_status` is currently `('active','inactive','suspended')` — see
`20260101090000_phase0_types.sql:30`. **`pending` does not exist yet.**

No index work needed: `profiles_account_status_idx` already exists
(`20260101090200:87`).

Add trigger `fn_confirm_pending_account`, fired `AFTER INSERT OR UPDATE OF
email_confirmed_at ON auth.users`, which flips `pending` → `active`. Include the
`revoke all … from public, anon, authenticated` line — the codebase's established
convention for privileged functions (see `20260101090900:354`).

### Phase 2 — Confirmation route and trigger wiring

- **New** `apps/web/src/app/auth/confirm/route.ts` — server route handler. Reads
  `token_hash` from the query string, calls `verifyOtp`, redirects. Must also handle
  `type=recovery` so password recovery shares this one verified path.
- **New** `apps/web/src/app/auth/confirmed/page.tsx` — bilingual success page.

**Why a database trigger and not a client-side update:** RLS deliberately blocks
`account_status` writes from the user themselves (`20260101090900:305-308`), and the web
app has no service-role key. GoTrue sets `email_confirmed_at` in the same transaction as
OTP verification, so a trigger on that column is atomic and cannot be forged from the
browser.

### Phase 3 — Edge Function

In `supabase/functions/admin-users/index.ts`, the `create_staff` action:

1. `email_confirm: true` → `false`
2. Explicitly set the profile to `pending` (the profiles trigger at
   `20260101090200:66` creates new rows as `active`, so this step is **required**)
3. Extract `link.properties.hashed_token` instead of discarding `action_link`
4. Send via Nodemailer; return a truthful `invitation_delivered` boolean

Also add a `resend_confirmation` action reusing the same path.

Existing `activity_logs` insert at `admin-users/index.ts:127-133` is kept and extended
to record `account_status: 'pending'`.

When SMTP env vars are absent, skip sending, return `invitation_delivered: false` with a
warning, and let the account stay `pending`. This makes the whole flow testable before
the app password exists.

### Phase 4 — Admin UI

- **New** `apps/web/src/components/users/invite-staff-dialog.tsx` — email, first/last
  name, contact, role (`staff` | `administrator`). Reuse the existing `Field` / `Button` /
  `Alert` primitives from `@/components/ui`.
- Wire it to the dead `createStaffUserAction`, adding the `role` field to its input type.
- Add an "Invite staff" button to `apps/web/src/app/admin/users/page.tsx`.
- Per-account: a `pending` badge, "Resend invitation", and visible delivery status.

### Phase 5 — Dependent updates

| File | Change |
|---|---|
| `apps/web/src/types/database.ts:8` | add `"pending"` to `AccountStatus` |
| `apps/web/src/app/admin/users/page.tsx:77-82` | add `pending` to status filter |
| `apps/web/src/components/users/user-actions.tsx:195-205` | show `pending` (read-only; not hand-assignable) |
| `apps/web/src/lib/format.ts` | label `pending` → "Awaiting e-mail confirmation" |
| `apps/web/src/lib/supabase/middleware.ts:73-80` | pass `reason=awaiting_confirmation` |
| `apps/web/src/lib/auth-guard.ts:17,29` | same |
| `apps/web/src/app/unauthorized/page.tsx` | render the new reason bilingually |
| `supabase/migrations/20260101090800:736` | `users_inactive` counts `<> 'active'`, so pending inflates it — split the metric |
| `apps/web/.env.example` | document the new SMTP variables |

Without the middleware and `auth-guard` changes, a `pending` user is redirected to
`/unauthorized?reason=account_inactive` — correct blocking, but the message would
incorrectly say the account was disabled rather than awaiting confirmation.

### Phase 6 — Deploy and verify

```bash
npx supabase functions deploy admin-users
npx supabase secrets set SMTP_HOST=… SMTP_PORT=… SMTP_USER=… SMTP_PASS=… SMTP_FROM=… SITE_URL=…
```

Verification checklist:

- [ ] Invite a throwaway address; mail arrives
- [ ] Link works; status flips `pending` → `active`
- [ ] Sign-in succeeds; the in-app notification appears
- [ ] **Re-clicking the same link fails** (proves single-use)
- [ ] Resend produces a fresh working link
- [ ] A `pending` user is correctly blocked at `/login`
- [ ] Delete the test account
- [ ] Confirm no service-role key or SMTP password appears in the bundle or in git

---

## 6. Environment variables

Edge Function secrets — **never committed**:

```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<dedicated system account>
SMTP_PASS=<Google app password>
SMTP_FROM="SBTF Mabini <address>"
SITE_URL=https://<production-domain>
```

> **Name collision — easy to get wrong.** The web app reads `NEXT_PUBLIC_SITE_URL`
> (`apps/web/src/lib/env.ts:11`). The function reads a *separate* `SITE_URL`
> (`admin-users/index.ts:136`). These are different variables and must be kept in sync
> by hand. Setting only the web app's will silently produce broken invitation links.

---

## 7. Still blocking / needs human input

- [ ] **Institutional sender name and signature block** — marked `TBD` in the template
      below. Needs a real decision.
- [ ] **Dedicated Gmail address** and its app password (requires 2FA enabled, then
      Google Account → Security → App passwords).
- [ ] **Production `uri_allow_list`** — currently **empty** on the cloud project.
      Note `supabase/config.toml` is local-only (per its own header) and does *not*
      apply to the cloud project. Must be set separately or invite links will be
      redirect-blocked in production.

---

## 8. Risks

- **Gmail sending limits** — roughly 500/day. Fine for staff invitations; **not viable**
  for driver self-registration. Revisit before that phase.
- **Deliverability** — bulk mail to unfamiliar recipients from a personal-domain Gmail
  frequently lands in spam. A municipal domain is the real fix.
- **Silent send failure** — the current code already has this bug. `invitation_delivered`
  becomes an explicit field so it cannot recur.
- **Token expiry** — invitations expire silently, which makes a usable resend action and
  a `pending` filter in the admin list necessary rather than optional.
- **Admin-invites-admin edge case** — a pending administrator cannot invite anyone, since
  `admin-users:66` requires an `active` caller. Expected behaviour, but it must be
  explained in the UI or it will look like a bug.

---

## 9. Explicitly out of scope

- **Driver / operator self-registration.** There is **no mobile app code in this
  repository** — `apps/` contains only `web`. Every "mobile registration" reference in
  the codebase is prose only (`admin/users/page.tsx:89` and `:144`,
  `components/users/user-actions.tsx:168`). Do not attempt to wire this up until the
  mobile app exists; there is nothing to attach to.
- **Supabase's own Auth mailer** — stays unconfigured; we own delivery.
- **Any change to the existing admin/staff accounts.** Both are `active` and
  pre-confirmed. This feature governs *newly invited* accounts only.
- **Seed data** — still not applied to any environment, by explicit decision.