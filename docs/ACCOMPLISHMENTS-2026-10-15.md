# Accomplishments — 2026-10-15

Session focused on unblocking the staff-side application pipeline that was
failing against the live Supabase project (`qdtmzgaxktebyhsxrgvf`). Four
distinct bugs were found and fixed, plus a hard guard on the recording step.
All work is verified by `validate:sql`, `typecheck`, `lint` and the 55-test
unit suite.

---

## 1. Verify / Reject documents failed with a runtime SQL error

**Symptom.** Staff could not verify or reject a document. Every attempt
surfaced a Postgres error and the document stayed `pending`.

**Root cause.** `fn_trg_document_written()` (migration `20260101090600`) passed a
`CASE` expression — typed `text` — into `fn_add_application_event`, whose third
parameter is the `public.application_event` enum. PostgreSQL cannot implicitly
coerce `text` to an enum, so the trigger raised:

```
42883: function public.fn_add_application_event(uuid, text, uuid, text) does not exist
```

The exception rolled the whole transaction back, so the status change never
persisted.

**Fix.** Migration `20260101092100_fix_document_verification_event.sql` recreates
the trigger with a typed `v_event public.application_event` variable and an
explicit cast. Applied to the live project and re-verified: the same call now
returns `error: null` and the document flips to `verified`.

## 2. Staff could not view an applicant's uploaded image

**Symptom.** The "Open file" button did not open the document.

**Root cause.** Two problems compounded. Signed URLs were minted at page render
with a 120-second lifetime, so any page left open past two minutes held a dead
link; and the button called `window.open()` *after* an `await`, which browsers
treat as a popup and silently block.

**Fix.** A streaming route handler, `apps/web/src/app/api/documents/[id]/route.ts`,
authenticates from cookies, relies on RLS, and streams the object with
`storage.download()` and `content-disposition: inline`. `review-panel.tsx` now
renders a plain `<a target="_blank" rel="noopener noreferrer">` — no popup, no
expiry. The dead `getDocumentUrlAction` and `getApplicationDocumentsWithUrls`
helpers were removed. Verified: `storage.download()` returns all four real files
(~94 KB–1.1 MB), and the route answers `307 → /login` when anonymous.

## 3. Appointments always showed 01:00

**Symptom.** A scheduled appointment always displayed as 1:00 AM, regardless of
the time entered.

**Root cause.** `<input type="datetime-local">` carries no zone, and the
server action did `new Date(value).toISOString()` — interpreting the wall-clock
value in the *server's* zone (UTC in production). A 9:00 AM booking was stored as
09:00 UTC and then re-rendered as 01:00 AM Philippine time. Display used
`toLocaleString` with no `timeZone`, so server and browser disagreed.

**Fix.**
- `constants.ts`: `APP_TIME_ZONE = "Asia/Manila"`, `APP_TIME_ZONE_OFFSET = "+08:00"`.
- `format.ts`: `formatDate` / `formatDateTime` now pin `timeZone`; new helpers
  `toDateTimeLocalValue()` (UTC instant → `YYYY-MM-DDTHH:mm` in Manila, via
  `Intl.formatToParts`) and `fromDateTimeLocalValue()` (field value → UTC ISO,
  pinned to `+08:00`).
- `actions/applications.ts`: scheduling and rescheduling use
  `fromDateTimeLocalValue()`.
- `handling-panel.tsx`: the reschedule prefill uses `toDateTimeLocalValue()`
  instead of `scheduled_at.slice(0, 16)`.

## 4. "Record application" errored every time

**Symptom.** The "Record application" button raised an error on every click, so
the stage never advanced and the button never went away.

**Root cause.** `fn_generate_verification_code()` (migration `20260101090500`)
built its code from `gen_random_bytes(12)`. That function belongs to `pgcrypto`,
which Supabase installs in the `extensions` schema, but the routine runs with
`set search_path = public, pg_temp`, so the name was unresolvable:

```
42883: function gen_random_bytes(integer) does not exist
```

`rpc_staff_record_application` calls this while issuing the franchise record
(`fn_staff_issue_franchise_record`), and the error rolled back the stage change
with it — the same failure class as bug #1.

**Fix.** Migration `20260101092200_fix_verification_code_randomness.sql` rewrites
the routine to draw its bytes from `gen_random_uuid()` — a core PostgreSQL
function that needs no extension and resolves under any `search_path` — via
`uuid_send()`. The 32-character alphabet mapping is unchanged.

## 5. Recording is now strictly one-time

**Context.** `rpc_staff_record_application` only rejected applications whose
`status` was no longer `pending`; it never inspected the pipeline `stage`. A
second call would re-run the stage update and its timeline/notification side
effects (the franchise number itself is idempotent).

**Fix.** Migration `20260101092300_guard_record_application_once.sql` recreates the
RPC with an explicit `stage = 'verified'` guard, so recording proceeds exactly
once and a repeat call is refused with a clear message.

---

## Verification

| Check | Result |
| --- | --- |
| `npm run validate:sql` | 649 statements, 0 errors / 0 warnings |
| `npm --workspace @sbtf/web run typecheck` | clean |
| `npm --workspace @sbtf/web run lint` | clean |
| `npm --workspace @sbtf/web run test:run` | 55 passed (7 files) |

Live diagnostics confirmed the bug-#1 fix end to end; bug #4 was reproduced
live as `42883: function gen_random_bytes(integer) does not exist`.

## Migrations to apply

`20260101092100`, `20260101092200` and `20260101092300` must all be applied to the
live project (`supabase db push`, or paste each into the Supabase SQL editor).
`20260101092100` is already applied; the other two are pending at the time of
writing.
