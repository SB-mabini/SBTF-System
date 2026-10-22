import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_picker.dart';
import 'models/app_notification.dart';
import 'models/appointment.dart';
import 'models/franchise_application.dart';
import 'models/franchise_record.dart';
import 'models/profile.dart';
import 'models/toda.dart';
import 'qr_scanner.dart';
import 'url_opener.dart';
import 'services/application_service.dart';
import 'services/appointment_service.dart';
import 'services/certificate_service.dart';
import 'services/document_service.dart';
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

/// Live appointment list (slice 9).
///
/// The home screen watches the same provider for its badge and the list
/// screen watches it for the rows, so the app opens a single Realtime
/// channel for appointments either way.
final myAppointmentsStreamProvider = StreamProvider<List<Appointment>>(
  (ref) => ref.watch(appointmentServiceProvider).watchMine(),
);
