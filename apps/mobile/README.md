# SBTF Mobile (Phase 3)

Driver/operator mobile application for the **SBTF System** — a Web and
Mobile-Based Franchising and Tricycle Driver Registration System for the
Municipality of Mabini, Batangas.

The web console (`apps/web`) is for administrators and staff. This app is for
**drivers and operators only**: registration, application submission, status
tracking and certificate access.

---

## 1. Platforms

The repository ships the Dart source and `pubspec.yaml` only. Generate the
platform scaffolding once, locally:

```bash
cd apps/mobile
flutter create --platforms=android,ios --org ph.gov.mabini .
```

This adds `android/` and `ios/` without touching `lib/` or `test/`. The
generated folders are git-ignored where appropriate; commit the pieces your
build pipeline needs.

> **Flutter ≥ 3.47 note.** Flutter's built-in Kotlin breaks plugins that
> still use the legacy Kotlin Gradle Plugin (`file_picker` among them). The
> flutter tool adds `android.builtInKotlin=false` and `android.newDsl=false`
> to `android/gradle.properties` automatically on the first interactive
> build; CI sets them explicitly after generating the platform. Keep them
> until every plugin has migrated to built-in Kotlin.

## 2. Run

Configuration is injected at build time with `--dart-define`. Only publishable
values are needed — the anon key is safe to ship because Row Level Security is
the actual authorisation boundary.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Add `--dart-define=SBTF_DEMO_MODE=true` to run the interface without a
database (sign-in is shown but disabled, every write blocked). With no
configuration at all, the app shows a diagnosis screen that prints the exact
run command above.

## 3. Quality gates

CI (`.github/workflows/flutter-ci.yml`) runs, on every push that touches
`apps/mobile`:

1. `flutter pub get`
2. `dart format --output=none --set-exit-if-changed lib test`
3. `flutter analyze`
4. `flutter test`
5. `flutter build apk --debug` (with `SUPABASE_URL` / `SUPABASE_ANON_KEY` secrets)

Run the same locally before pushing:

```bash
dart format lib test
flutter analyze
flutter test
```

## 4. Structure

```
lib/
  main.dart                     entry point; initialises Supabase only when configured
  app/
    app.dart                    root widget + theme; chooses gate vs. config screen
    config_missing_screen.dart  shown when --dart-define is absent
  core/
    env.dart                    build-time configuration
    theme.dart                  8px grid, desaturated palette, Material 3
    providers.dart              supabase client, auth state, profile providers
    models/profile.dart         mirrors public.profiles
  features/
    auth/
      session_guard.dart        pure session policy (unit-tested)
      auth_gate.dart            maps decisions to screens
      login_screen.dart         sign-in
      registration_screen.dart  driver self-registration
      email_verification_screen.dart
    home/
      home_screen.dart          profile header + feature tiles
test/
  session_guard_test.dart       9 precedence cases
  profile_test.dart
  env_test.dart
  config_missing_screen_test.dart
```

## 5. Slice status

| Slice | Scope | Status |
|---|---|---|
| 1 | Project skeleton, config, theme, session guard | Implemented |
| 2 | Auth screens (login, register, verify), home shell | Implemented |
| 3 | New + renewal application submission | Planned |
| 4 | Application status tracking | Planned |
| 5 | Document upload + replacement | Planned |
| 6 | Certificate + QR viewing | Planned |
| 7 | Notifications | Planned |
| 8 | Polish, offline handling, release build | Planned |

The home screen labels every not-yet-built feature with its slice and a "soon"
badge rather than pretending it works.

## 6. Hard rules (do not weaken)

These mirror the database invariants; the app must never try to bypass them.

1. **Drivers only.** Self-registration always provisions the `driver` role. The
   role is read from Supabase Auth `raw_app_meta_data`, which only the service
   role can write — a client cannot self-assign `staff` or `administrator`.
2. **Own storage folder.** Document uploads go only to the caller's own
   `{profile_id}/` folder; `rpc_driver_replace_document` re-checks this.
3. **One pending application** per application type per driver.
4. **Exactly four documents** per application (member association certificate,
   OR/CR, cedula, barangay clearance).
5. **Writes only through the audited RPCs.** Triggers write the audit trail;
   never insert audit rows from the client, and never bypass an RPC with a raw
   table write.
