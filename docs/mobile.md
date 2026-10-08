# Mobile Application — Phase 3

The driver/operator application for the SBTF System. Flutter + Riverpod, talking to
the same Supabase project as the web console. There is no mobile-specific backend:
the database, its RPCs, RLS policies and triggers are the entire contract.

**Last updated:** 2026-10-08 · slices 1–2 implemented, 3–8 planned (§7).

---

## 1. Architecture carry-overs

Decisions from Phase 0–2 that this app inherits without change:

1. **RLS is the only real authorisation.** Every screen renders what the caller's own
   token is allowed to read; a bypassed navigation check gains nothing.
2. **Roles come from Supabase Auth app metadata**, which only the service role can
   write. Self-registration here always provisions `driver`, whatever the client asks
   for. The session guard *also* refuses non-driver profiles (§3), so a staff account
   cannot use this app even with a valid session.
3. **Own storage folder.** Uploads live under `{profile_id}/`; both
   `rpc_driver_submit_application` and `rpc_driver_replace_document` re-check the
   path server-side.
4. **Writes only through the audited RPCs.** Triggers write the audit trail and the
   application timeline; the app never inserts audit rows and never bypasses an RPC.
5. **One pending application per type, exactly four documents** (member association
   certificate, OR/CR, cedula, barangay clearance); each file ≤ 10 MB, PDF/JPEG/PNG.
6. **Rejected documents are replaceable.** `rpc_driver_replace_document`
   (migration 14) resets a rejected/pending document to `pending` and the existing
   trigger writes the `document_replaced` audit row. Slice 5 builds the UI on this.

---

## 2. Implemented slices (1–2)

| Slice | Delivered |
|---|---|
| 1 — skeleton | `pubspec.yaml`, `--dart-define` configuration (`lib/core/env.dart`), 8px-grid Material 3 theme, Riverpod providers, `Profile` model, session-guard policy with unit tests |
| 2 — auth + shell | Sign-in, self-registration, e-mail verification (resend), session gate with refusal cards, home screen with profile header and six honestly-labelled feature tiles, config-missing diagnosis screen, demo mode (form shown disabled, never hidden) |

Deliberately **not** built yet: any write path, document handling, notifications,
QR scanning. The home screen marks each of those with the slice that will deliver it.

---

## 3. Session-guard decision table

The policy is pure logic in `lib/features/auth/session_guard.dart`, evaluated in this
order (first match wins), and unit-tested with the precedence cases included:

| # | Condition | Decision | Screen |
|---|---|---|---|
| 1 | No session | `requireLogin` | Sign-in |
| 2 | Session, e-mail not confirmed | `requireEmailVerification` | Verification notice + resend |
| 3 | Confirmed, no profile row | `profileMissing` | Refusal card |
| 4 | Profile role ≠ driver | `refuseNonDriver` | Refusal card ("use the web console") |
| 5 | Account suspended | `refuseSuspended` | Refusal card |
| 6 | Account not active | `refuseInactive` | Refusal card |
| 7 | Otherwise | `allow` | Home |

Profile loading shows a spinner; a failed profile fetch shows an error card with a
retry button rather than silently looping.

---

## 4. Data contact points

Everything the app reads or will write, and through which surface:

| Data | Direction | Surface |
|---|---|---|
| Own profile | read | `select … from profiles where auth_user_id = …` (RLS returns own row only) |
| Auth session | read | `Supabase.auth.onAuthStateChange` |
| TODA list, barangays | read | plain select (reference data, anon-readable by policy) |
| Application submission | write (slice 3) | `rpc_driver_submit_application(jsonb)` |
| Document replacement | write (slice 5) | `rpc_driver_replace_document(…)` |
| Own applications, documents, timeline, notifications | read (slices 4, 5, 7) | RLS-scoped selects |
| Storage upload | write (slice 5) | storage bucket `franchise-documents`, own folder only |
| Certificate + QR | read (slice 6) | own `franchise_records` rows; verification stays on the public web page |

---

## 5. Build and run

```bash
cd apps/mobile
flutter create --platforms=android,ios --org ph.gov.mabini .   # once, generates android/ ios/
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>

# Preview without a database (sign-in shown disabled, writes blocked):
flutter run --dart-define=SBTF_DEMO_MODE=true
```

Quality gates (identical to CI):

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

With no configuration the app boots into a diagnosis screen that prints the exact run
command — it never crashes on a missing define.

---

## 6. Functional acceptance cases (MA-01 … MA-14)

Record **Actual** and **Pass** per run; note device, Flutter version and project ref.

| ID | Action | Expected result | Actual | Pass |
|---|---|---|---|---|
| MA-01 | Launch a build with no `--dart-define` values | Config-missing screen with the exact run command and a copy button | | |
| MA-02 | Launch with `SBTF_DEMO_MODE=true` | Sign-in form visible but disabled under a preview banner; nothing hidden | | |
| MA-03 | Register with valid details | Account created; e-mail verification screen shown; resend available | | |
| MA-04 | Register with a password shorter than 8 characters | Client-side validation refuses before any network call | | |
| MA-05 | Register with mismatched confirmation password | Client-side validation refuses | | |
| MA-06 | Sign in before confirming the e-mail | Routed to the verification screen; resend issues a new confirmation | | |
| MA-07 | Sign in as a confirmed, active driver | Home screen with profile header ("Driver / operator · account active") | | |
| MA-08 | Sign in with a wrong password | Clear inline error; no navigation, no crash | | |
| MA-09 | Sign in with a staff/administrator account | `refuseNonDriver` card: municipal roles belong on the web console | | |
| MA-10 | Sign in with a suspended driver account | `refuseSuspended` card naming the state | | |
| MA-11 | Inspect the home header | Full name from the profile (generated column, with fallback), initials avatar | | |
| MA-12 | Sign out | Confirmation dialog first, then session gone and sign-in screen shown | | |
| MA-13 | Close and relaunch after signing in | Session restored; straight to home without re-entering credentials | | |
| MA-14 | Inspect the six feature tiles | Each shows its slice and a "soon" badge; none pretend to work | | |

---

## 7. Roadmap — slices 3–8

| Slice | Scope | Notes |
|---|---|---|
| 3 | New + renewal application submission | Form wizard over `rpc_driver_submit_application`; storage upload to own folder first; one pending application per type enforced server-side |
| 4 | Application status tracking | RLS reads of `franchise_applications` + `application_status_history`; Realtime subscription for status changes |
| 5 | Document upload + replacement | `file_picker` + compression; replacement via `rpc_driver_replace_document` when staff rejected a copy |
| 6 | Certificate + QR viewing | Own `franchise_records`; signed URL download; scanner (`mobile_scanner`) resolves through the public web verification endpoint |
| 7 | Notifications | Own `notifications` rows + Realtime; mark-as-read via the existing update grant |
| 8 | Hardening & release | Offline behaviour, error taxonomy parity with the web console's `/setup-required`, signed release builds |
