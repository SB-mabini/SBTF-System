import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_picker.dart';
import 'onboarding/onboarding_store.dart';
import 'models/announcement.dart';
import 'models/app_notification.dart';
import 'models/appointment.dart';
import 'models/franchise_application.dart';
import 'models/franchise_record.dart';
import 'models/form_request.dart';
import 'models/profile.dart';
import 'models/toda.dart';
import 'qr_scanner.dart';
import 'url_opener.dart';
import 'services/announcement_service.dart';
import 'services/agreement_service.dart';
import 'services/application_service.dart';
import 'services/appointment_service.dart';
import 'services/certificate_service.dart';
import 'services/document_service.dart';
import 'services/form_request_service.dart';
import 'services/notification_service.dart';
import 'services/reference_service.dart';

/// The shared Supabase client.
///
/// Reads only when the app actually connected to a project (see `main.dart`).
/// In preview/demo mode this provider is never watched, because nothing is
/// allowed to touch a database there.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// First-run onboarding state, read by the launch gate and by Settings.
///
/// One instance per provider container keeps the in-memory state and the
/// persisted values in sync while the app is running.
final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  return OnboardingStore();
});

/// Mirrors an accepted User Agreement to the signed-in driver's profile.
final agreementServiceProvider = Provider<AgreementService>((ref) {
  return const AgreementService();
});

/// Emits every auth transition (sign-in, sign-out, token refresh, initial
/// session restore). The [AuthGate] maps these to screens.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// The signed-in driver's own `profiles` row, fetched through RLS with the
/// caller's own token. Returns null when there is no session yet.
///
/// The profile is what decides whether the session may proceed: roles and
/// account status live here, and Row Level Security only ever returns the
/// caller's own row, so this read cannot leak another account.
///
/// It watches [authStateChangesProvider] so it re-fetches whenever the session
/// changes (sign-in, sign-out, restore), rather than returning a stale null.
final profileProvider = FutureProvider<Profile?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value?.session?.user ?? client.auth.currentUser;
  if (user == null) return null;

  final row = await client
      .from('profiles')
      .select()
      .eq('auth_user_id', user.id)
      .maybeSingle();

  if (row == null) return null;
  return Profile.fromMap(row);
});

/// Auth events that can change which rows the driver is allowed to see.
///
/// `tokenRefreshed` is included deliberately: the token is also refreshed after
/// a permission/profile change, and re-reading then is cheap and keeps stale
/// data from surviving.
const Set<AuthChangeEvent> _driverDataRefreshEvents = {
  AuthChangeEvent.signedIn,
  AuthChangeEvent.signedOut,
  AuthChangeEvent.tokenRefreshed,
  AuthChangeEvent.userUpdated,
  AuthChangeEvent.passwordRecovery,
};

/// Clears every driver-owned cache when the session changes.
///
/// Without this, Riverpod keeps the previous account's applications,
/// notifications, certificates and appointments in memory after a sign-out or
/// account switch, and the next user briefly sees or reuses that data. The
/// AuthGate keeps this provider alive; the actual invalidation happens on the
/// auth event, not on every widget build.
final authSessionSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AuthState>>(authStateChangesProvider, (previous, next) {
    final event = next.value?.event;
    if (event == null) return;
    if (!_driverDataRefreshEvents.contains(event)) return;
    _invalidateDriverData(ref);

    // Onboarding is completed before sign-in, so the acceptance is recorded
    // locally first. Once the driver is signed in, mirror it to the profile.
    if (event == AuthChangeEvent.signedIn) {
      final acceptance = ref.read(onboardingStoreProvider).state;
      ref.read(agreementServiceProvider).sync(acceptance).ignore();
    }
  });
});

/// Invalidates every user-scoped provider. Kept in one place so a newly added
/// data provider cannot be forgotten in the sign-out path.
void _invalidateDriverData(Ref ref) {
  ref.invalidate(profileProvider);

  ref.invalidate(myApplicationsProvider);
  ref.invalidate(activeApplicationProvider);
  ref.invalidate(applicationDetailProvider);
  ref.invalidate(myApplicationsStreamProvider);

  ref.invalidate(myFormRequestsProvider);
  ref.invalidate(openFormRequestProvider);
  ref.invalidate(latestRejectedFormRequestProvider);
  ref.invalidate(myFormRequestsStreamProvider);

  ref.invalidate(myRecordsProvider);
  ref.invalidate(activeRecordProvider);
  ref.invalidate(myRecordsStreamProvider);

  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadNotificationCountProvider);
  ref.invalidate(notificationsStreamProvider);
  ref.invalidate(unreadNotificationCountStreamProvider);

  ref.invalidate(myAppointmentsStreamProvider);

  ref.invalidate(announcementsProvider);
  ref.invalidate(announcementsStreamProvider);
}

// ---------------------------------------------------------------------------
// Slice services
//
// One provider per slice's data service. Each is lazy: it is only constructed
// when a screen actually watches it, so preview/demo mode (which never reaches
// these screens) never touches `Supabase.instance`.
// ---------------------------------------------------------------------------

/// Slice 3 support — TODA and barangay pickers.
final referenceServiceProvider = Provider<ReferenceService>(
  (ref) => ReferenceService(ref.watch(supabaseClientProvider)),
);

/// Slices 3 and 4 — submission and application status.
final applicationServiceProvider = Provider<ApplicationService>(
  (ref) => ApplicationService(ref.watch(supabaseClientProvider)),
);

/// Slice 5 — document upload and replacement.
final documentServiceProvider = Provider<DocumentService>(
  (ref) => DocumentService(ref.watch(supabaseClientProvider)),
);

/// Request-form-first workflow — the driver's request letter.
final formRequestServiceProvider = Provider<FormRequestService>(
  (ref) => FormRequestService(ref.watch(supabaseClientProvider)),
);

/// Slice 6 — certificates, QR and verification.
final certificateServiceProvider = Provider<CertificateService>(
  (ref) => CertificateService(ref.watch(supabaseClientProvider)),
);

/// Slice 7 — notifications.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(supabaseClientProvider)),
);

/// Slice 9 — in-person appointments booked by the municipal staff.
final appointmentServiceProvider = Provider<AppointmentService>(
  (ref) => AppointmentService(ref.watch(supabaseClientProvider)),
);

/// Office announcements addressed to the driver.
final announcementServiceProvider = Provider<AnnouncementService>(
  (ref) => AnnouncementService(ref.watch(supabaseClientProvider)),
);

/// Slice 3 + 5 — picks a documentary requirement from the device.
///
/// Injectable so widget tests can supply a fake without touching the platform
/// file-chooser channel.
final documentPickerProvider = Provider<DocumentPicker>(
  (ref) => const FileSelectorDocumentPicker(),
);

/// Slice 6 — builds the camera view that reads a certificate QR code.
///
/// Injectable so widget tests can supply a fake that reports a code, since a
/// real camera cannot run under `flutter test`.
final qrScannerViewBuilderProvider = Provider<QrScannerViewBuilder>(
  (ref) => buildCameraQrScanner,
);

/// Slice 6 — opens a certificate or verification link in the browser.
///
/// Injectable so widget tests do not touch the platform URL-launcher channel.
final urlLauncherProvider = Provider<UrlLauncher>((ref) => launchInBrowser);

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

/// Accredited, active TODAs for the application form.
final todaListProvider = FutureProvider<List<Toda>>(
  (ref) => ref.watch(referenceServiceProvider).listTodas(),
);

/// Barangays of Mabini, in official sort order.
final barangayListProvider = FutureProvider<List<Barangay>>(
  (ref) => ref.watch(referenceServiceProvider).listBarangays(),
);

/// The driver's own applications, newest first (slice 4).
final myApplicationsProvider = FutureProvider<List<FranchiseApplication>>(
  (ref) => ref.watch(applicationServiceProvider).listMine(),
);

/// All of the driver's form requests, newest first.
final myFormRequestsProvider = FutureProvider<List<FormRequest>>(
  (ref) => ref.watch(formRequestServiceProvider).listMine(),
);

/// The request occupying the driver's open slot, if any.
final openFormRequestProvider = FutureProvider<FormRequest?>(
  (ref) => ref.watch(formRequestServiceProvider).openRequest(),
);

/// The newest rejected request the driver can edit and resubmit.
final latestRejectedFormRequestProvider = FutureProvider<FormRequest?>(
  (ref) => ref.watch(formRequestServiceProvider).latestRejected(),
);

/// Live form-request status changes (staff approval / rejection).
final myFormRequestsStreamProvider = StreamProvider<List<FormRequest>>(
  (ref) => ref.watch(formRequestServiceProvider).watchMine(),
);

/// The application to open by default: newest pending, else newest overall.
final activeApplicationProvider = FutureProvider<FranchiseApplication?>(
  (ref) => ref.watch(applicationServiceProvider).activeApplication(),
);

/// One application with its documents and timeline (slice 4/5).
final applicationDetailProvider =
    FutureProvider.family<FranchiseApplication?, String>(
  (ref, id) => ref.watch(applicationServiceProvider).getById(id),
);

/// The driver's own issued franchises (slice 6).
final myRecordsProvider = FutureProvider<List<FranchiseRecord>>(
  (ref) => ref.watch(certificateServiceProvider).listMine(),
);

/// The franchise to feature on the home screen (slice 6).
final activeRecordProvider = FutureProvider<FranchiseRecord?>(
  (ref) => ref.watch(certificateServiceProvider).activeRecord(),
);

/// The public base address encoded into a certificate QR code (slice 6).
///
/// Null when `certificate_verification_base_url` is unset; the QR then falls
/// back to carrying the bare verification code, which resolves identically.
final verificationBaseUrlProvider = FutureProvider<String?>(
  (ref) => ref.watch(certificateServiceProvider).verificationBaseUrl(),
);

/// The driver's notifications, newest first (slice 7).
final notificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationServiceProvider).listMine(),
);

/// Unread notification count for the badge (slice 7).
final unreadNotificationCountProvider = FutureProvider<int>(
  (ref) => ref.watch(notificationServiceProvider).unreadCount(),
);

/// Published office announcements, newest first.
final announcementsProvider = FutureProvider<List<Announcement>>(
  (ref) => ref.watch(announcementServiceProvider).listPublished(),
);

// ---------------------------------------------------------------------------
// Realtime providers (slices 4, 6, 7)
//
// Realtime applies the same RLS policies as normal queries, so a driver only
// receives change events for rows their own token may read.
// ---------------------------------------------------------------------------

/// Live application list for the status tracker (slice 4).
final myApplicationsStreamProvider = StreamProvider<List<FranchiseApplication>>(
  (ref) => ref.watch(applicationServiceProvider).watchMine(),
);

/// Live notification feed (slice 7).
final notificationsStreamProvider = StreamProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationServiceProvider).watchMine(),
);

/// Live unread count (slice 7).
final unreadNotificationCountStreamProvider = StreamProvider<int>(
  (ref) => ref.watch(notificationServiceProvider).watchUnreadCount(),
);

/// Live franchise records (slice 6).
final myRecordsStreamProvider = StreamProvider<List<FranchiseRecord>>(
  (ref) => ref.watch(certificateServiceProvider).watchMine(),
);

/// Live published announcements, so a new notice appears without a refresh.
final announcementsStreamProvider = StreamProvider<List<Announcement>>(
  (ref) => ref.watch(announcementServiceProvider).watchPublished(),
);

/// Live appointment list (slice 9).
///
/// The home screen watches the same provider for its badge and the list
/// screen watches it for the rows, so the app opens a single Realtime
/// channel for appointments either way.
final myAppointmentsStreamProvider = StreamProvider<List<Appointment>>(
  (ref) => ref.watch(appointmentServiceProvider).watchMine(),
);
