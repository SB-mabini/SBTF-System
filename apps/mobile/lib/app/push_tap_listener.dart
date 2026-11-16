import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notification_navigation.dart';
import '../core/services/push_notification_service.dart';

/// Root navigator and messenger keys.
///
/// A push tap arrives above `MaterialApp` (from FCM, not from a widget), so
/// navigation has to be addressed through these keys rather than through a
/// `BuildContext` beneath the Navigator.
final GlobalKey<NavigatorState> pushNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> pushMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Listens for notification taps (foreground, background resume and cold
/// start) and opens the record they point at.
///
/// It also triggers the push service's one-time initialisation after the first
/// frame, so the Android permission prompt appears over the app instead of a
/// blank launch screen.
class PushTapListener extends ConsumerStatefulWidget {
  const PushTapListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushTapListener> createState() => _PushTapListenerState();
}

class _PushTapListenerState extends ConsumerState<PushTapListener> {
  StreamSubscription<String>? _subscription;
  String? _lastOpenedId;
  DateTime? _lastOpenedAt;

  @override
  void initState() {
    super.initState();

    final service = ref.read(pushNotificationServiceProvider);
    _subscription = service.opened.listen(_open);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await service.initialize();
      final initial = service.consumeInitialTap();
      if (initial != null) await _open(initial);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _open(String notificationId) async {
    if (!mounted) return;

    // FCM can report the same launch both through getInitialMessage() and
    // onMessageOpenedApp(); opening twice would stack the same screen.
    final now = DateTime.now();
    if (_lastOpenedId == notificationId &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastOpenedId = notificationId;
    _lastOpenedAt = now;

    final navigator = await _waitForNavigator();
    if (navigator == null) return;

    await NotificationOpener(ref).openById(
      notificationId,
      navigator: navigator,
      messenger: pushMessengerKey.currentState,
    );
  }

  /// On a cold start the tap can arrive before the first route is installed.
  Future<NavigatorState?> _waitForNavigator() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final navigator = pushNavigatorKey.currentState;
      if (navigator != null) return navigator;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
