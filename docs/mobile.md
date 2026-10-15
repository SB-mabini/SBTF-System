# Mobile Application — Phase 3

The driver/operator application for the SBTF System. Flutter + Riverpod, talking to
the same Supabase project as the web console. There is no mobile-specific backend:
the database, its RPCs, RLS policies and triggers are the entire contract.

**Last updated:** 2026-10-15 · slices 1–8 implemented: every screen (1–7), the
slice-8 hardening (offline behaviour, error-surface parity with the web console,
signed release builds) and a visual pass over the whole app — see §2, §5, §7 and §8.

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
   trigger writes the `document_replaced` audit row. Slice 5's document manager
   builds the UI on this.

---

## 2. Implemented slices (1–8)

| Slice | Delivered |
|---|---|
| 1 — skeleton | `pubspec.yaml`, `--dart-define` configuration (`lib/core/env.dart`), 8px-grid Material 3 theme, Riverpod providers, `Profile` model, session-guard policy with unit tests |
| 2 — auth + shell | Sign-in, self-registration, e-mail verification (resend), session gate with refusal cards, home screen with profile header and six honestly-labelled feature tiles, config-missing diagnosis screen, demo mode (form shown disabled, never hidden) |
| 3 — application wizard | New/renewal franchise wizard (`lib/features/application/application_form_screen.dart`) on top of `ApplicationService.submit()`: five steps (type/location, operator, vehicle, documents, review), TODA/barangay/renewal-record pickers, per-requirement upload to the caller's own storage folder via `file_selector`, client-side validation mirroring the RPC, and a submitted screen showing the application number. The two slice-3 home tiles are now live |
| 4 — status tracker | Application status tracker (`lib/features/application/application_list_screen.dart`, `application_detail_screen.dart`) over `ApplicationService`: the list shows the driver's own applications newest-first with status chips and stays current through the Realtime stream; the detail screen shows the status, any rejection reason, application details, per-document verification state (with staff remarks) and the timeline. The slice-4 home tile is now live |
| 5 — document manager | Standalone document manager (`lib/features/documents/document_manager_screen.dart`, `application_documents_screen.dart`) over `DocumentService`: reuses the slice-4 list as an application chooser, then shows all four requirements with their verification state and staff remarks; a rejected or pending copy can be replaced (uploaded to the caller's own `{profile_id}/{application_id}/` folder, then reset to `pending` through `rpc_driver_replace_document`) while the application is under review; a verified copy or a decided application cannot be replaced and says why. Files view through a short-lived signed URL (images inline, PDFs noted as browser-only). The slice-5 home tile is now live |
| 6 — certificate + QR | Certificate and QR viewer (`lib/features/certificate/certificate_list_screen.dart`, `certificate_detail_screen.dart`, `certificate_verify_screen.dart`) over `CertificateService`: the list shows the driver's own franchises newest-first with a state chip (active / expiring / expired / archived) and stays current through the Realtime stream; the detail renders the same QR payload the web console prints (the public verification URL when `certificate_verification_base_url` is set, otherwise the bare code), the record details and the verification code, and opens the certificate PDF through a short-lived signed URL; the scanner reads a QR with `mobile_scanner` and resolves it — or a hand-typed code — through the public `rpc_verify_certificate`, which returns only a masked name and the franchise dates. The slice-6 home tile is now live |
| 7 — notifications | Notification feed (`lib/features/notifications/notification_list_screen.dart`) over `NotificationService`: the list shows the driver's own notifications newest-first with an unread highlight and a "New" badge and stays current through the Realtime stream; tapping a row marks it read and, when the row carries a deep-link target, opens that application's tracker or that certificate (re-read by id, so a stale link can only ever resolve to the caller's own row); "Mark all as read" clears the badge in one update; a row can be deleted on its own by long-pressing its card, or everything already read in one go through "Clear read" — both behind a confirm and disabled in demo mode, so a long feed stays easy to scan. Rows are created only by SECURITY DEFINER functions and triggers; the client may only mark its own rows read and delete them. The slice-7 home tile is now live and carries the live unread count |
| 8 — hardening & release | Hardening pass over the finished screens, with no new screen and no new dependency: one classified error surface for every slice (`lib/core/widgets/error_view.dart`), a stronger error taxonomy with a reason + actionable hint mirroring the web console (`lib/core/app_error.dart`), the session gate classifying and retrying its own failures (`lib/features/auth/auth_gate.dart`), and optional release signing for the Android build (`android/app/build.gradle.kts`, `android/key.properties.example`, §5) |

### Slice data layer (3–8) — implemented

Every slice's database contract is already wrapped in a typed service; the slice 3
through 7 screens are now built (§2), and slice 8 hardened them in place rather than
adding a screen. This layer changes nothing in `supabase/migrations` — it only reads
that contract.

| Slice | Service (`lib/core/services/`) | Delivered |
|---|---|---|
| 3 support | `reference_service.dart` | `listTodas()`, `listBarangays()`, `findToda()` |
| 3 + 4 | `application_service.dart` | `submit()`, `listMine()`, `activeApplication()`, `getById()`, `listTimeline()`, `watchMine()`, `watchById()` |
| 5 | `document_service.dart` | `uploadDocument()`, `replaceDocument()`, `signedDocumentUrl()`, `removeUpload()`, `buildStoragePath()` |
| 6 | `certificate_service.dart` | `listMine()`, `getById()`, `activeRecord()`, `certificateSignedUrl()`, `verify()`, `verificationBaseUrl()`, `watchMine()` |
| 7 | `notification_service.dart` | `listMine()`, `unreadCount()`, `markRead()`, `markAllRead()`, `delete()`, `deleteRead()`, `watchMine()`, `watchUnreadCount()` |

Supporting pieces:

- **Models** (`lib/core/models/`) — `Toda`/`Barangay`, `FranchiseApplication` with
  `ApplicationSubmission`/`ApplicationDocumentUpload`, `FranchiseDocument`,
  `ApplicationEvent`, `FranchiseRecord`, `CertificateVerification`,
  `AppNotification`. Every `fromMap` parses defensively.
- **Domain constants and QR helpers** — `lib/core/constants.dart` (document types,
  upload limits, storage buckets) and `lib/core/verification.dart`, mirroring the
  web console so a code built by either client resolves identically.
- **Error taxonomy** — `lib/core/app_error.dart` (`AppFailure` + `classifyAppError`)
  is parity with the web console's `src/lib/supabase/errors.ts`: the same
  schema-missing, unreachable, unauthorised and unknown classification, plus the
  mobile-only `businessRule` and `demoBlocked` kinds. Each failure carries a
  one-sentence message and, where there is something the driver can do, an
  actionable `hint` — the reason/hint pair the web console shows. Transport
  failures (`SocketException`, timeouts, HTTP 0/502/503/504) and PostgREST's split
  `details`/`hint` are all classified, and a `blocking` flag separates an
  environment failure (a session-level refusal is recoverable by signing in again;
  a project-level one is blocking).
- **File picking** — `lib/core/document_picker.dart` wraps Flutter's `file_selector`
  (Android-safe: it defers `compileSdk` to the app, unlike `file_picker` 8.x) behind
  a small `DocumentPicker` interface, injected through `documentPickerProvider` so
  the wizard and the document manager stay testable without the platform channel.
- **Camera and browser seams** — `lib/core/qr_scanner.dart` wraps `mobile_scanner`
  behind a `QrScannerViewBuilder` and `lib/core/url_opener.dart` wraps `url_launcher`
  behind a `UrlLauncher`, both injected through `providers.dart`. The verifier and the
  certificate actions therefore stay testable without a camera or the platform
  channel. The QR itself is drawn by `qr_flutter`, which is pure Dart and needs no
  seam.
- **Shared status chips** — `lib/core/widgets/status_chip.dart` is the single place
  the application/document status vocabulary and colours live, so the tracker and
  the document manager render a given state identically.
- **One error surface** — `lib/core/widgets/error_view.dart` (`ErrorView` +
  `CenteredScrollView`) is the single classified error/empty/loading surface every
  slice uses, so an offline failure reads the same on the tracker, the documents,
  the certificates and the notifications, each with its hint and one Retry. Before
  slice 8 every screen drew its own error view.
- **Notification labels** — `lib/core/notification_format.dart` keeps the
  `notification_type` → label vocabulary in one place, mirroring the web console's
  `notification-list.tsx`; an unknown type is humanised rather than shown raw.
- **Providers** (`lib/core/providers.dart`) — one per service, plus data providers
  and Realtime stream providers, all lazy so preview/demo mode never touches
  `Supabase.instance`.

Both write paths call `ensureWritable()` first, so preview/demo mode throws
`AppFailure.demoBlocked` rather than reaching a database that is not there. The
pure logic (validation, payload building, error classification, verification and
storage-path construction) is covered by unit tests under `test/`.

There is no unbuilt screen left: all six home tiles are live (slices 3–7). Slice 8
hardened them in place — offline behaviour, error-surface parity with the web
console and signed release builds (§5, §7) — rather than adding a screen.

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

Profile loading shows a spinner; a failed profile fetch is classified through
`classifyAppError` and shown as an error card with its message, its hint and a retry
button — an offline launch reads "Could not reach the municipal service" rather than
showing a raw exception, and never silently loops.

---

## 4. Data contact points

Everything the app reads or writes, and through which surface. The "Surface"
column is the database contract; "Implementation" names the service or provider
that wraps it (§2).

| Data | Direction | Surface | Implementation |
|---|---|---|---|
| Own profile | read | `profiles` by `auth_user_id` (RLS: own row only) | `profileProvider` |
| Auth session | read | `Supabase.auth.onAuthStateChange` | `authStateChangesProvider` |
| TODA list, barangays | read | `todas`, `barangays` (reference, anon-readable) | `ReferenceService.listTodas()` / `listBarangays()` |
| Application submission | write (3) | `rpc_driver_submit_application(jsonb)` | `ApplicationService.submit()` via the wizard (`application_form_screen.dart`) |
| Own applications + timeline | read (4) | RLS-scoped selects | `ApplicationService.listMine()` / `getById()` / `listTimeline()`; Realtime `watchMine()` / `watchById()`; rendered by the status tracker (`application_list_screen.dart` / `application_detail_screen.dart`) |
| Document upload | write (5) | bucket `franchise-documents`, own folder only | `DocumentService.uploadDocument()` from the wizard's documents step and the document manager's replace action |
| Document replacement | write (5) | `rpc_driver_replace_document(…)` | `DocumentService.replaceDocument()` via the document manager (`application_documents_screen.dart`) |
| Document viewing | read (5) | bucket `franchise-documents` signed URL | `DocumentService.signedDocumentUrl()`, rendered by the document manager |
| Certificate + signed download | read (6) | own `franchise_records`; bucket `certificates` signed URL | `CertificateService.listMine()` / `certificateSignedUrl()` |
| Certificate verification | read (6, public) | `rpc_verify_certificate(code)` (masked name) | `CertificateService.verify()` |
| Own notifications | read + mark-read + delete (7) | `notifications` select; `update` sets `read`/`read_at`; `delete` removes the caller's own rows | `NotificationService.listMine()` / `watchMine()` / `unreadCount()` / `watchUnreadCount()` / `markRead()` / `markAllRead()` / `delete()` / `deleteRead()`, rendered by the notification list (`notification_list_screen.dart`) |

Failure on any of these is classified, not shown raw: `classifyAppError` turns a
transport or PostgREST failure into a message plus an actionable hint (§2), and every
screen renders it through the shared `ErrorView` with a retry. The session gate
classifies the profile and auth-stream failures the same way, so an offline launch or
an unmigrated project explains itself instead of showing a raw exception.

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

### Release builds

Release signing is optional and secret-free by default: without
`android/key.properties` the release build falls back to the debug keys, so
`flutter build apk --debug`, `flutter test` and CI keep working with no secrets.
To sign a real release:

```bash
cd apps/mobile/android/app
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

cd ..
cp key.properties.example key.properties   # then fill in the four values
```

`android/key.properties` and every `*.jks`/`*.keystore` are git-ignored — never
commit them. Then build:

```bash
flutter build apk --release          # installable APK
flutter build appbundle --release    # Play Store bundle (.aab)
```

---

## 6. Functional acceptance cases (MA-01 … MA-47)

Record **Actual** and **Pass** per run; note device, Flutter version and project ref.

| ID | Action | Expected result | Actual | Pass |
|---|---|---|---|---|
| MA-01 | Launch a build with no `--dart-define` values | Config-missing screen with the exact run command and a copy button | | |
| MA-02 | Launch with `SBTF_DEMO_MODE=true` | Sign-in form visible but disabled under a preview banner; nothing hidden | | |
| MA-03 | Register with valid details | Account created; e-mail verification screen shown; resend available | | |
| MA-04 | Register with a password shorter than 8 characters | Client-side validation refuses before any network call | | |
| MA-05 | Register with mismatched confirmation password | Client-side validation refuses | | |
| MA-06 | Sign in before confirming the e-mail | Routed to the verification screen; resend issues a new confirmation | | |
| MA-07 | Sign in as a confirmed, active driver | Home dashboard with the hero card showing the driver's name, e-mail, "Driver / Operator" pill and account-state pill | | |
| MA-08 | Sign in with a wrong password | Clear inline error; no navigation, no crash | | |
| MA-09 | Sign in with a staff/administrator account | `refuseNonDriver` card: municipal roles belong on the web console | | |
| MA-10 | Sign in with a suspended driver account | `refuseSuspended` card naming the state | | |
| MA-11 | Inspect the hero card | Full name from the profile (generated column, with fallback) and the gold-ringed initials avatar | | |
| MA-12 | Sign out | Confirmation dialog first, then session gone and sign-in screen shown | | |
| MA-13 | Close and relaunch after signing in | Session restored; straight to home without re-entering credentials | | |
| MA-14 | Inspect the dashboard destinations | Every destination is live: under "Services", new franchise and renewal open the wizard, documents open the document manager and certificate & QR opens the certificate list; under "Track & updates", application status opens the tracker and notifications open the feed with the live unread badge; nothing pretends to work | | |
| MA-15 | Tap "New franchise application" | Wizard opens on step 1 with "New franchise" selected and the TODA picker populated | | |
| MA-16 | Tap Next without choosing a TODA | Inline "Select an accredited TODA." refusal; no network call | | |
| MA-17 | Upload all four requirements | Each shows its file name; PDF/JPEG/PNG only, ≤ 10 MB; files land under `{profile_id}/staging/` | | |
| MA-18 | Submit a complete application | Success screen shows the application number; the server stays the authority on duplicates | | |
| MA-19 | Tap "My application status" with no applications | Empty state explains that submitted applications appear here, with a button to start one | | |
| MA-20 | Tap "My application status" with applications | The driver's own applications, newest first, each with a status chip | | |
| MA-21 | Open an application | Tracker shows status, details, per-document verification state (with staff remarks) and the timeline | | |
| MA-22 | Staff rejects a document/application | List and tracker reflect the new status and rejection reason on the next Realtime event, without a manual refresh | | |
| MA-23 | Tap "My documents" | Chooser lists the driver's own applications, newest first, each opening its requirements | | |
| MA-24 | Open an application in the document manager | All four requirements in canonical order, each with its verification chip, file name and any staff remarks; a requirement with no row reads "Not on file" | | |
| MA-25 | Replace a rejected (or pending) copy | Picker opens; PDF/JPEG/PNG ≤ 10 MB; the corrected file uploads under `{profile_id}/{application_id}/`, then `rpc_driver_replace_document` resets it to `pending`; a success message appears and the state refreshes | | |
| MA-26 | Try to replace a verified copy, or any copy on a decided application | No Replace action; the screen explains that verified copies and decided applications cannot be replaced | | |
| MA-27 | View a stored document | An image previews inline from a short-lived signed URL; a PDF states that preview needs the browser, without failing | | |
| MA-28 | Tap "Certificate & QR code" with no franchise | Empty state explains when a certificate appears, with a button to verify a code | | |
| MA-29 | Tap "Certificate & QR code" with franchises | The driver's own franchises newest first, each with a state chip (active, expiring soon, expired, archived); the row opens its detail | | |
| MA-30 | Open a certificate | QR carrying the public verification URL (or the bare code when `certificate_verification_base_url` is unset), the verification code, the record details and the state sentence | | |
| MA-31 | Open the certificate PDF | A short-lived signed URL hands off to the browser; a record with no file yet disables the action and explains why | | |
| MA-32 | Scan a certificate QR (or type its code) | Result shows valid / expired / archived / not-found with the franchise number, TODA and dates, and the operator name masked; an unknown code reports "Certificate not found"; the typed path resolves identically to a scan | | |
| MA-33 | Tap "Notifications" with no notifications | Empty state explains that applications, decisions, document remarks, renewal reminders and account changes appear here | | |
| MA-34 | Tap "Notifications" with notifications | The driver's own notifications newest-first, unread rows highlighted with a "New" badge, each with its type label and timestamp | | |
| MA-35 | Open an unread notification | The row is marked read (the home badge drops on the next Realtime event); a row that points at an application or a certificate opens that tracker or detail | | |
| MA-36 | Tap "Mark all as read" | Every notification is marked read in one update; the action is disabled when nothing is unread | | |
| MA-37 | Open a notification whose target was withdrawn | A clear "no longer available" message appears; no crash and no stray navigation | | |
| MA-38 | Turn off connectivity, then open any data screen (tracker, documents, certificates, notifications) | The classified "Could not reach the municipal service" surface with its connection hint and a Retry — not a raw exception string; the same surface appears on every screen | | |
| MA-39 | Turn off connectivity, then relaunch with a stored session | The session gate shows a classified "Service unavailable" card with a hint and a Retry button; no blank screen and no login loop | | |
| MA-40 | Launch against a project whose migrations were never applied | A classified "The database is not ready" surface (schema missing), not a raw PostgREST string; the app does not bounce between sign-in and a blank screen | | |
| MA-41 | Build a release APK/AAB with `android/key.properties` present, then without it | With it, the artifact is signed with the release key (Play accepts it); without it, the build still succeeds using the debug key | | |
| MA-42 | Inspect the home dashboard | Gradient hero card with the driver's name, e-mail and the "Driver / Operator" and account-state pills over a gold-ringed initials avatar; a "Services" grid and a "Track & updates" group, all sharing one card/section language | | |
| MA-43 | Inspect any list, detail or scanner screen | Cards, buttons, inputs, chips, dialogs and banners all draw from the shared theme (16px cards with a soft shadow, pill status chips with a state dot); no screen looks visually detached from the others | | |
| MA-44 | Open an empty list (applications, certificates, notifications) | The same empty-state panel: a tinted circular icon medallion, a title, a supporting line and — where useful — a single action | | |
| MA-45 | Cold-start the app on Android | The launch window is the municipal purple; the first Flutter frame fades in over it with no white flash | | |
| MA-46 | Delete a single notification | Long-pressing a card raises a delete prompt; confirming removes just that row (the home badge drops on the next Realtime event) and Cancel leaves the feed untouched | | |
| MA-47 | Clear read notifications | The "Clear read" action asks for confirmation, then removes every row already read and keeps the unread ones; it is disabled when nothing is read | | |

---

## 7. Roadmap — slices 3–8

Every slice is implemented: slices 3–7 built the screens (§2), slice 8 hardened them
and the release path. The SQL contract in `supabase/migrations` is fixed — the
mobile app only reads it.

| Slice | Scope | Service layer | Remaining (UI) |
|---|---|---|---|
| 3 | New + renewal application submission | `application_service.dart`, `reference_service.dart` | **Implemented** — wizard in `lib/features/application/application_form_screen.dart`; documents uploaded to the own folder first; server enforces one pending application per type |
| 4 | Application status tracking | `application_service.dart` (reads + Realtime) | **Implemented** — tracker in `lib/features/application/application_list_screen.dart` (live list, newest first) and `application_detail_screen.dart` (status, rejection reason, per-document state, timeline) |
| 5 | Document upload + replacement | `document_service.dart` | **Implemented** — document manager in `lib/features/documents/document_manager_screen.dart` (application chooser) and `application_documents_screen.dart` (per-requirement state, replace a rejected/pending copy via `rpc_driver_replace_document`, signed-URL view) |
| 6 | Certificate + QR viewing | `certificate_service.dart` | **Implemented** — certificate list and detail in `lib/features/certificate/certificate_list_screen.dart` (state chips, Realtime) and `certificate_detail_screen.dart` (QR via `qr_flutter`, signed-URL PDF through `url_launcher`, copy link), plus the scanner in `certificate_verify_screen.dart` (`mobile_scanner`, with a typed-code fallback) resolving through the public `rpc_verify_certificate` |
| 7 | Notifications | `notification_service.dart` (reads + Realtime) | **Implemented** — feed in `lib/features/notifications/notification_list_screen.dart` (unread highlight + "New" badge, live via Realtime, mark-as-read on open, mark-all-as-read, long-press a card to delete one row and a bulk "Clear read", both confirmed) with deep links into the slice-4 tracker and slice-6 certificate detail; the home tile carries the live unread count |
| 8 | Hardening & release | error taxonomy in `lib/core/app_error.dart`; no new SQL | **Implemented** — one classified error surface (`lib/core/widgets/error_view.dart`) used by every slice; `app_error.dart` extended to the web console's reason + hint parity (transport/status detection, session-vs-project authorisation, `blocking`); the session gate classifies and retries its own failures; optional release signing in `android/app/build.gradle.kts` with a debug fallback and `android/key.properties.example`, documented in §5 |

---

## 8. Design system

The visual layer is defined once, in `lib/core/theme.dart`, and applied everywhere
through Material 3 component themes — screens do not hand-roll colours, radii,
shadows or text sizes.

- **Tokens.** `AppColors` (the Quiet Civic palette: deep-purple authority, gold
  seal, neutral-dominant), `AppSpacing` (8px grid), `AppRadius` (an 8/12/16/20/pill
  corner scale), `AppShadows` (one soft resting shadow, one raised shadow) and
  `AppGradients` (the hero and gold gradients). `AppTheme.light` wires them into the
  `ColorScheme` and every component theme: app bar, cards, inputs, buttons, chips,
  dialogs, bottom sheets, snack bars, list tiles, dividers and progress.
- **Shared widgets** (`lib/core/widgets/`): one error surface (`ErrorView` +
  `CenteredScrollView`, §2 slice 8), one empty-state panel (`EmptyState`), one
  inline message strip (`AppBanner`, tone-based) and one section label
  (`SectionHeader`). A status is always rendered through a `StatusChip` helper, so
  its colour and shape never vary by call site.
- **Home dashboard.** The landing screen is a dashboard, not a list of tiles: a
  gradient hero card (sign-in identity, gold-ringed initials avatar, role and
  account-state pills, a faint municipal-seal watermark), a two-column "Services"
  grid (new franchise, renewal, documents, certificate & QR) and a "Track & updates"
  group (application status, notifications with the live unread badge).
- **Depth and type.** White cards on a cool neutral background carry one soft shadow
  plus a hairline border and a 16px radius; the type scale uses the platform font
  with a disciplined size/weight/line-height ramp — no new dependency.
- **Launch screen.** The Android launch window is the municipal purple
  (`android/app/src/main/res/values/colors.xml`, `drawable*/launch_background.xml`,
  and `values-v31` / `values-night-v31` for the Android 12+ splash), so the app boots
  on-brand.
