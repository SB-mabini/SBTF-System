# Staff Invitation Email — Implemented Template

**Status:** implemented 13 November 2026.
**Source of truth:** [`supabase/templates/invite.html`](../supabase/templates/invite.html).
**Subject:** `SBTF staff account invitation — SBTF System`

Delivery is Supabase Auth's mailer, not Nodemailer. The `admin-users` Edge Function calls
`inviteUserByEmail()`, and the hosted project's Gmail SMTP sends the message.

## Link

The template contains:

```
{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=invite
```

`/auth/confirm` verifies the token hash with `verifyOtp({ type: "invite" })` and forwards the
visitor to `/accept-invitation`, where they choose a password. That form signs them out and
redirects to `/login?notice=password-set`.

Do **not** replace this with Supabase's default `{{ .ConfirmationURL }}`. It lands on
GoTrue `/verify`, returns the session in the URL fragment, and the web app cannot consume
it.

## Copy rules

- Tagalog first, English second. The primary readers are municipal staff.
- Keep the “one-time link, limited time” reminder in both languages.
- State that an administrator must approve the account before the console opens.
- Never put a Go-template placeholder inside an HTML comment. GoTrue renders placeholders
  wherever they appear, including comments.

## Hosted project

`supabase/config.toml` only applies the template to `supabase start`. For the hosted
project, update:

- Dashboard → Authentication → Email Templates → **Invite user**, or
- the Management API keys `mailer_subjects_invite` and `mailer_templates_invite_content`.

Also confirm `site_url` is the production origin (`https://sbtf-system.vercel.app`) with no
trailing slash, because the template builds its link from `.SiteURL`. See
[`deployment.md`](./deployment.md) §3.1.
