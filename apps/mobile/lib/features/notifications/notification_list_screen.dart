import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/date_format.dart';
import '../../core/env.dart';
import '../../core/models/app_notification.dart';
import '../../core/notification_format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../application/application_detail_screen.dart';
import '../appointments/appointment_detail_screen.dart';
import '../certificate/certificate_detail_screen.dart';

/// The driver's notification feed, newest first — slice 7.
///
/// Backed by [notificationsStreamProvider], so a staff decision or a renewal
/// reminder reaches the driver without a manual refresh; RLS limits the stream
/// to the caller's own rows. Rows are created only by SECURITY DEFINER
/// functions and triggers — the app may read its own rows and mark them read
/// (`20260101090900_phase0_rls_policies.sql`), never write the content.
///
/// Tapping a notification marks it read and, when it carries a deep-link target
/// (`targetsApplication` / `targetsRecord` / `targetsAppointment`), opens that
/// application's tracker, that certificate or that appointment. The target is
/// re-read by id, so a stale link can only ever resolve to the caller's own
/// row.
///
/// A row can also be deleted — long-press a card to raise the delete prompt, or
/// clear everything already read in bulk from the "Clear read" action — so an
/// account that has accumulated notices stays easy to scan. Both confirm first
/// and are disabled in demo mode, where the database is never written.
class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends ConsumerState<NotificationListScreen> {
  bool _markingAll = false;
  bool _clearing = false;

  /// Writes are refused in demo mode (the service guards them), so the delete
  /// actions are disabled rather than failing after the fact.
  bool get _demo => currentEnv.isDemoMode;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final unread = notificationsAsync.valueOrNull
            ?.where((notification) => !notification.read)
            .length ??
        0;
    final readCount = notificationsAsync.valueOrNull
            ?.where((notification) => notification.read)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Clear read notifications',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _demo || readCount == 0 || _clearing ? null : _clearRead,
          ),
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
            onPressed: unread == 0 || _markingAll ? null : _markAll,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsStreamProvider.future),
          child: notificationsAsync.when(
            loading: () => const CenteredScrollView(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => CenteredScrollView(
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(notificationsStreamProvider),
              ),
            ),
            data: (notifications) {
              if (notifications.isEmpty) {
                return const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'No notifications yet',
                  message: 'Applications, decisions, document remarks, renewal '
                      'reminders and account changes appear here.',
                );
              }
              final sorted = [...notifications]..sort(_newestFirst);
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.compact),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: sorted.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _Summary(unread: unread);
                  final notification = sorted[index - 1];
                  return _NotificationCard(
                    notification: notification,
                    onOpen: () => _handleTap(notification),
                    onLongPress: _demo ? null : () => _delete(notification),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Newest first; a row without a timestamp sinks rather than jumping.
  int _newestFirst(AppNotification a, AppNotification b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  Future<void> _handleTap(AppNotification notification) async {
    if (!notification.read) {
      try {
        await ref.read(notificationServiceProvider).markRead(notification.id);
      } on AppFailure {
        // The Realtime stream will correct the state; a failed mark must not
        // stop the driver from opening what the notification points at.
      }
      if (!mounted) return;
    }

    if (notification.targetsApplication) {
      await _openApplication(notification.targetId!);
    } else if (notification.targetsRecord) {
      await _openRecord(notification.targetId!);
    } else if (notification.targetsAppointment) {
      await _openAppointment(notification.targetId!);
    }
  }

  Future<void> _openApplication(String id) async {
    final application = await _load(
      () => ref.read(applicationServiceProvider).getById(id),
      'That application is no longer available.',
    );
    if (application == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationDetailScreen(application: application),
      ),
    );
  }

  Future<void> _openRecord(String id) async {
    final record = await _load(
      () => ref.read(certificateServiceProvider).getById(id),
      'That certificate is no longer available.',
    );
    if (record == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CertificateDetailScreen(record: record),
      ),
    );
  }

  Future<void> _openAppointment(String id) async {
    final appointment = await _load(
      () => ref.read(appointmentServiceProvider).getById(id),
      'That appointment is no longer available.',
    );
    if (appointment == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(appointment: appointment),
      ),
    );
  }

  /// Runs [fetch], surfacing a friendly message for a missing row or a failure.
  Future<T?> _load<T>(
      Future<T?> Function() fetch, String missingMessage) async {
    try {
      final value = await fetch();
      if (value == null && mounted) _showMessage(missingMessage);
      return value;
    } on AppFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
      return null;
    }
  }

  Future<void> _markAll() async {
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationServiceProvider).markAllRead();
      if (mounted) _showMessage('All notifications marked as read.');
    } on AppFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  /// Deletes one notification after the driver confirms.
  Future<void> _delete(AppNotification notification) async {
    final confirmed = await _confirm(
      title: 'Delete Notification',
      message: 'Are you sure you want to delete this notification?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(notificationServiceProvider).delete(notification.id);
      if (mounted) _showMessage('Notification deleted.');
    } on AppFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
    }
  }

  /// Deletes every notification the driver has already read, after confirming.
  Future<void> _clearRead() async {
    final confirmed = await _confirm(
      title: 'Clear read notifications?',
      message: 'Every notification you have already read will be removed. '
          'Unread ones are kept. This cannot be undone.',
      confirmLabel: 'Clear',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await ref.read(notificationServiceProvider).deleteRead();
      if (mounted) _showMessage('Read notifications cleared.');
    } on AppFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  /// Asks the driver to confirm an irreversible action, matching the sign-out
  /// dialog's shape: a plain Cancel and a danger-filled confirm.
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dangerFill,
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onOpen,
    this.onLongPress,
  });

  final AppNotification notification;
  final VoidCallback onOpen;

  /// Raises the delete prompt on a long-press; null in demo mode, where writes
  /// are blocked, so the gesture is inert.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    final hasTarget = notification.targetsApplication ||
        notification.targetsRecord ||
        notification.targetsAppointment;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      color: unread ? AppColors.primaryTint : AppColors.surface,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.compact,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:
                      unread ? AppColors.primaryTintStrong : AppColors.greyFill,
                  borderRadius: AppRadius.box,
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 16,
                  color: unread ? AppColors.primary : AppColors.inkMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(
                              color: AppColors.inkStrong,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const _NewBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    _TypeChip(
                      label:
                          notificationTypeLabel(notification.notificationType),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: AppColors.inkStrong,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _timestampLine(notification),
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                    if (hasTarget) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.open_in_new,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _targetLabel(notification),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timestampLine(AppNotification notification) {
    final created = formatDateTime(notification.createdAt);
    if (notification.read && notification.readAt != null) {
      return '$created · read ${formatDateTime(notification.readAt)}';
    }
    return created;
  }

  /// The deep-link hint under a row that points at something.
  String _targetLabel(AppNotification notification) {
    if (notification.targetsApplication) return 'Open application';
    if (notification.targetsRecord) return 'Open certificate';
    return 'Open appointment';
  }
}

/// The count of unread rows, or a reassuring line once everything is read —
/// the same wording the web console uses — plus a one-line hint, since a
/// long-press is otherwise invisible.
class _Summary extends StatelessWidget {
  const _Summary({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final text = unread == 0
        ? 'Everything has been read.'
        : '$unread unread notification${unread == 1 ? '' : 's'}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 2),
          const Text(
            'Long-press a notification to delete it.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.card,
      ),
      child: const Text(
        'New',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.greyFill,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
