# Staff Invitation Email — Bilingual Template (DRAFT)

**Status:** draft for review. Copy has not been approved. Two fields marked `TBD` need a
human decision before implementation.

Design notes for whoever implements this:

- Template lives in the `admin-users` Edge Function, sent via Nodemailer.
- Tagalog first, English second. The primary readers are barangay staff.
- The link href is `{SITE_URL}/auth/confirm?token_hash={hashed_token}`.
- **Do not hardcode an expiry figure in the copy.** Supabase controls token lifetime;
  state the real value at implementation time. The wording below deliberately says
  "limited time" instead of inventing a number that could become wrong.
- Replace `TBD` fields before shipping. Do not ship with a `TBD` visible to users.

---

## Subject line

```
Kumpirmahin ang iyong email — SBTF System | Confirm your email — SBTF System
```

---

## Body

```html
<div style="font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
            max-width: 560px; margin: 0 auto; color: #1a1a1a;">

  <p style="font-size: 15px; line-height: 1.6;">
    Magandang araw, <strong>[first_name]</strong>,
  </p>

  <p style="font-size: 15px; line-height: 1.6;">
    Natanggap namin ang kagustuhan mong makapasok sa <strong>SBTF System</strong>
    ng <em>TBD — institutional name</em>. Mangyaring kumpirmahin ang iyong email
    address upang ma-activate ang iyong account.
  </p>

  <p style="margin: 28px 0;">
    <a href="{{CONFIRM_LINK}}"
       style="background: #271564; color: #ffffff; padding: 13px 24px;
              border-radius: 8px; text-decoration: none; font-weight: 600;
              display: inline-block;">
      Kumpirmahin ang aking email &rarr;
    </a>
  </p>

  <p style="font-size: 13px; color: #666; line-height: 1.6;">
    <em>Paalala: gumagana ang link na ito nang isang beses lamang at may
    limitadong oras.</em>
  </p>

  <hr style="border: none; border-top: 1px solid #e5e5e5; margin: 28px 0;" />

  <p style="font-size: 15px; line-height: 1.6;">
    Good day, <strong>[first_name]</strong>,
  </p>

  <p style="font-size: 15px; line-height: 1.6;">
    We have received your request to join the <strong>SBTF System</strong> of
    <em>TBD — institutional name</em>. Please confirm your email address to activate
    your account.
  </p>

  <p style="margin: 28px 0;">
    <a href="{{CONFIRM_LINK}}"
       style="background: #271564; color: #ffffff; padding: 13px 24px;
              border-radius: 8px; text-decoration: none; font-weight: 600;
              display: inline-block;">
      Confirm my email &rarr;
    </a>
  </p>

  <p style="font-size: 13px; color: #666; line-height: 1.6;">
    <em>Note: this link works only once and expires after a limited time.</em>
  </p>

  <hr style="border: none; border-top: 1px solid #e5e5e5; margin: 28px 0;" />

  <p style="font-size: 14px; line-height: 1.6;">
    Salamat mula sa,<br />
    <strong>TBD — sender name / office</strong><br />
    <span style="color: #666; font-size: 13px;">TBD — postal address</span>
  </p>

  <p style="font-size: 12px; color: #888; line-height: 1.6; margin-top: 24px;">
    Kung hindi kayo nag-request ng account na ito, maaari itong i-ignore.
    Ang mga link sa account ay gumagana isang beses lamang.<br /><br />
    If you did not request this account, you may safely ignore this message.
    Account links are single-use.
  </p>

</div>
```

---

## Plain-text alternative

Required as `text` alongside the HTML part — some recipients and mail clients will not
render HTML at all.

```
Kumpirmahin ang iyong email — SBTF System

Magandang arow, [first_name],

Natanggap namin ang kagustuhan mong makapasok sa SBTF System ng
TBD — institutional name. Mangyaring kumpirmahin ang iyong email address
upang ma-activate ang iyong account.

Kumpirmahin ang aking email:
{{CONFIRM_LINK}}

Paalala: gumagana ang link na ito nang isang beses lamang at may limitadong oras.

---

Good day, [first_name],

We have received your request to join the SBTF System of
TBD — institutional name. Please confirm your email address to activate
your account.

Confirm my email:
{{CONFIRM_LINK}}

Note: this link works only once and expires after a limited time.

---

Salamat mula sa,
TBD — sender name / office
TBD — postal address

Kung hindi kayo nag-request ng account na ito, maaari itong i-ignore.
If you did not request this account, you may safely ignore this message.
```

---

## Placeholder reference

| Placeholder | Source |
|---|---|
| `[first_name]` | `user_metadata.first_name`, set at invite time |
| `{{CONFIRM_LINK}}` | `{SITE_URL}/auth/confirm?token_hash={hashed_token}` |
| `TBD — institutional name` | **Needs human decision** |
| `TBD — sender name / office` | **Needs human decision** |
| `TBD — postal address` | **Needs human decision** |