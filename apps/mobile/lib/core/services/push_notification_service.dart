import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env.dart';

/// Android channel used for every MTOP push. The same id is sent by the
/// `push-dispatch` Edge Function as `android.notification.channel_id`, so a
/// background message and a foreground one land in the same channel.
const String pushChannelId = 'sbtf_updates';
const String pushChannelName = 'MTOP Updates';

/// Background isolate entry point. FCM requires a top-level function.
///
/// The dispatcher always sends a `notification` payload, so Android draws the
/// notification itself while the app is closed or backgrounded; this handler
/// only has to make Firebase available in the isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Device push notifications — announcements, decisions, appointments,
/// renewals and other system updates.
///
/// Responsibilities:
///  * initialise Firebase (silently when `google-services.json` is absent, so
///    debug/CI builds without Firebase still run);
///  * create the high-importance Android channel and ask for permission;
///  * keep `public.device_tokens` in step with the signed-in account — on
///    sign-in, on FCM token rotation and after the app resumes;
///  * show a notification when a message arrives while the app is foreground;
///  * expose taps (foreground, background and cold start) as a stream of
///    `notifications.id` values, which the app resolves through RLS and opens
///    with the same routing as the in-app feed.
class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService(this.ref);

  final Ref ref;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _opened =
      StreamController<String>.broadcast();

  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _message;
  StreamSubscription<RemoteMessage>? _messageOpened;
  StreamSubscription<AuthState>? _authChanges;

  String? _lastToken;
  String? _pendingTap;
  bool _initialised = false;

  /// Taps on a push, as `notifications.id` values.
  Stream<String> get opened => _opened.stream;

  /// True once Firebase initialised and messaging is usable on this build.
  bool get isAvailable => _messaging != null;

  /// The tap that launched the app, if any. Consumed once: a cold start must
  /// navigate after the first frame, which may be later than the FCM callback.
  String? consumeInitialTap() {
    final tap = _pendingTap;
    _pendingTap = null;
    return tap;
  }

  Future<void> initialize() async {
    if (_initialised) return;
    // Preview/demo builds never talk to a project, so there is nothing to
    // register and no Firebase config to initialise.
    if (!currentEnv.isConfigured || currentEnv.isDemoMode) return;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      // No google-services.json (local/CI build without Firebase). In-app
      // notifications keep working; push is simply unavailable.
      return;
    }

    _initialised = true;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _prepareLocalNotifications();
    await _requestPermission();
    await _syncToken();

    _tokenRefresh = messaging.onTokenRefresh.listen((token) {
      _lastToken = token;
      unawaited(_registerToken(token));
    });
    _message = FirebaseMessaging.onMessage.listen(_showForeground);
    _messageOpened = FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    // Late sign-in (the app boots signed out, or a different driver replaces
    // the session) and token rotation both have to reach device_tokens.
    _authChanges = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.userUpdated) {
        // Never call back into Supabase synchronously from the auth callback.
        Future.microtask(_syncToken);
      }
    });

    WidgetsBinding.instance.addObserver(this);

    final initial = await messaging.getInitialMessage();
    if (initial != null) _rememberTap(initial);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A driver who signs in while onboarding, or whose token was revoked
    // while the app was in the background, is reconciled on resume.
    if (state == AppLifecycleState.resumed) Future.microtask(_syncToken);
  }

  Future<void> _prepareLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_sbtf');
    const settings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) _emitTap(id);
      },
    );

    const channel = AndroidNotificationChannel(
      pushChannelId,
      pushChannelName,
      description: 'Announcements, application updates and reminders.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Denied permission is not an error: the driver still has the in-app
      // feed, and the token request below simply returns null.
    }
  }

  /// Registers the current FCM token for the signed-in profile.
  Future<void> _syncToken() async {
    final messaging = _messaging;
    if (messaging == null) return;

    try {
      if (Supabase.instance.client.auth.currentUser == null) return;
      final token = await messaging.getToken();
      if (token == null) return;
      _lastToken = token;
      await _registerToken(token);
    } catch (_) {
      // Offline or permission denied; the next resume/sign-in retries.
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      if (Supabase.instance.client.auth.currentUser == null) return;
      await Supabase.instance.client.rpc(
        'rpc_register_device_token',
        params: {
          'p_token': token,
          'p_platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );
    } catch (_) {
      // The RPC is retried on the next auth/resume event.
    }
  }

  /// Removes this device from the caller's account. Call **before** signing
  /// out, while the session still exists — otherwise the phone keeps receiving
  /// the previous driver's notifications.
  Future<void> unregisterCurrent() async {
    final token = _lastToken ?? await _messaging?.getToken();
    if (token == null) return;
    try {
      await Supabase.instance.client.rpc(
        'rpc_unregister_device_token',
        params: {'p_token': token},
      );
      _lastToken = null;
    } catch (_) {
      // Sign-out must not be blocked by a failed token cleanup.
    }
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['message'];
    final id = message.data['notification_id'];
    if (title == null || body == null) return;

    const androidDetails = AndroidNotificationDetails(
      pushChannelId,
      pushChannelName,
      channelDescription:
          'Announcements, application updates and reminders.',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    _localNotifications.show(
      notification?.hashCode ?? body.hashCode,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: id,
    );
  }

  void _handleOpen(RemoteMessage message) {
    final id = message.data['notification_id'];
    if (id != null && id.isNotEmpty) _emitTap(id);
  }

  void _rememberTap(RemoteMessage message) {
    final id = message.data['notification_id'];
    if (id == null || id.isEmpty) return;
    // Deliberately not emitted on the stream: the tap handler consumes it once
    // the first frame is up, which is the only moment navigation is safe.
    _pendingTap = id;
  }

  void _emitTap(String id) {
    if (!_opened.isClosed) _opened.add(id);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefresh?.cancel();
    _message?.cancel();
    _messageOpened?.cancel();
    _authChanges?.cancel();
    _opened.close();
  }
}

/// One instance for the whole app: [main] initialises it before `runApp`, and
/// the tap listener reuses the same stream for the lifetime of the process.
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});
