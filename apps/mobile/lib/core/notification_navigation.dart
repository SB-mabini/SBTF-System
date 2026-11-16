import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_error.dart';
import 'models/app_notification.dart';
import 'providers.dart';
import 'theme.dart';
import '../features/announcements/announcement_detail_screen.dart';
import '../features/application/application_detail_screen.dart';
import '../features/application/request_form_screen.dart';
import '../features/appointments/appointment_detail_screen.dart';
import '../features/certificate/certificate_detail_screen.dart';

/// Opens the record a notification points at.
///
/// Shared by the in-app feed and by push taps: a tap that arrives in the
/// background or cold start must land on exactly the same screen as a tap in
/// the list. The target is always re-read by id through RLS, so a stale or
/// forged link can only ever resolve to the caller's own row.
///
/// Navigation is expressed in terms of a [NavigatorState] rather than a
/// [BuildContext] because a push tap is handled above the `MaterialApp` — at
/// that point there is no context beneath the Navigator to push from.
class NotificationOpener {
  const NotificationOpener(this.ref);

  final WidgetRef ref;

  /// Marks [notification] read (best effort) and opens its target.
  Future<void> open(
    AppNotification notification, {
    required NavigatorState navigator,
    ScaffoldMessengerState? messenger,
  }) async {
    if (!notification.read) {
      try {
        await ref.read(notificationServiceProvider).markRead(notification.id);
      } on AppFailure {
        // The realtime feed corrects itself; a failed mark must never stop the
        // driver from opening what the notification is about.
      }
    }

    if (!navigator.mounted) return;

    if (notification.targetsApplication) {
      await _openApplication(notification.targetId!, navigator, messenger);
    } else if (notification.targetsRecord) {
      await _openRecord(notification.targetId!, navigator, messenger);
    } else if (notification.targetsAppointment) {
      await _openAppointment(notification.targetId!, navigator, messenger);
    } else if (notification.targetsFormRequest) {
      await _openFormRequest(notification.targetId!, navigator, messenger);
    } else if (notification.targetsAnnouncement) {
      await _openAnnouncement(notification.targetId!, navigator, messenger);
    }
  }

  /// Resolves a notification id (from a push payload) and opens it.
  Future<void> openById(
    String notificationId, {
    required NavigatorState navigator,
    ScaffoldMessengerState? messenger,
  }) async {
    if (notificationId.isEmpty) return;

    AppNotification? notification;
    try {
      notification =
          await ref.read(notificationServiceProvider).getById(notificationId);
    } on AppFailure catch (failure) {
      _show(messenger, failure.message, isError: true);
      return;
    }

    if (notification == null) {
      _show(messenger, 'That notification is no longer available.');
      return;
    }

    await open(notification, navigator: navigator, messenger: messenger);
  }

  Future<void> _openAnnouncement(
    String id,
    NavigatorState navigator,
    ScaffoldMessengerState? messenger,
  ) async {
    final announcement = await _load(
      () => ref.read(announcementServiceProvider).getById(id),
      'That announcement is no longer available.',
      messenger,
    );
    if (announcement == null || !navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AnnouncementDetailScreen(announcement: announcement),
      ),
    );
  }

  Future<void> _openFormRequest(
    String id,
    NavigatorState navigator,
    ScaffoldMessengerState? messenger,
  ) async {
    final request = await _load(
      () => ref.read(formRequestServiceProvider).getById(id),
      'That form request is no longer available.',
      messenger,
    );
    if (request == null || !navigator.mounted) return;

    ref.invalidate(openFormRequestProvider);
    ref.invalidate(latestRejectedFormRequestProvider);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RequestFormScreen(existing: request),
      ),
    );
  }

  Future<void> _openApplication(
    String id,
    NavigatorState navigator,
    ScaffoldMessengerState? messenger,
  ) async {
    final application = await _load(
      () => ref.read(applicationServiceProvider).getById(id),
      'That application is no longer available.',
      messenger,
    );
    if (application == null || !navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationDetailScreen(application: application),
      ),
    );
  }

  Future<void> _openRecord(
    String id,
    NavigatorState navigator,
    ScaffoldMessengerState? messenger,
  ) async {
    final record = await _load(
      () => ref.read(certificateServiceProvider).getById(id),
      'That certificate is no longer available.',
      messenger,
    );
    if (record == null || !navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CertificateDetailScreen(record: record),
      ),
    );
  }

  Future<void> _openAppointment(
    String id,
    NavigatorState navigator,
    ScaffoldMessengerState? messenger,
  ) async {
    final appointment = await _load(
      () => ref.read(appointmentServiceProvider).getById(id),
      'That appointment is no longer available.',
      messenger,
    );
    if (appointment == null || !navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(appointment: appointment),
      ),
    );
  }

  /// Runs [fetch], surfacing a friendly message for a missing row or a failure.
  Future<T?> _load<T>(
    Future<T?> Function() fetch,
    String missingMessage,
    ScaffoldMessengerState? messenger,
  ) async {
    try {
      final value = await fetch();
      if (value == null) _show(messenger, missingMessage);
      return value;
    } on AppFailure catch (failure) {
      _show(messenger, failure.message, isError: true);
      return null;
    }
  }

  void _show(
    ScaffoldMessengerState? messenger,
    String message, {
    bool isError = false,
  }) {
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }
}
