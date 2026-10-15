import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import 'service_base.dart';

/// The driver's in-app notification feed — slice 7.
///
/// Rows are created only by SECURITY DEFINER functions and triggers; the client
/// may read its own rows, mark them read, and delete them
/// (`20260101090900_phase0_rls_policies.sql`).
class NotificationService extends SupabaseService {
  NotificationService(super.client);

  /// The caller's notifications, newest first.
  Future<List<AppNotification>> listMine({int limit = 50}) {
    return guard(() async {
      final rows = await client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) =>
              AppNotification.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// How many of the caller's notifications are unread — the badge count.
  Future<int> unreadCount() {
    return guard(() async {
      final response = await client
          .from('notifications')
          .select('id')
          .eq('read', false)
          .count(CountOption.exact);
      return response.count;
    });
  }

  /// Marks one notification as read.
  Future<void> markRead(String id) {
    return guard(() async {
      ensureWritable();
      await client
          .from('notifications')
          .update({
            'read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('read', false);
    });
  }

  /// Marks every unread notification of the caller as read.
  ///
  /// The RLS update policy already restricts the rows to the caller's own, so
  /// no user filter is needed — but `read = false` avoids rewriting rows that
  /// are already read (and keeps `read_at` meaningful).
  Future<void> markAllRead() {
    return guard(() async {
      ensureWritable();
      await client.from('notifications').update({
        'read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('read', false);
    });
  }

  /// Deletes one of the caller's notifications.
  Future<void> delete(String id) {
    return guard(() async {
      ensureWritable();
      await client.from('notifications').delete().eq('id', id);
    });
  }

  /// Deletes every notification the caller has already read.
  Future<void> deleteRead() {
    return guard(() async {
      ensureWritable();
      await client.from('notifications').delete().eq('read', true);
    });
  }

  /// Live notification feed (RLS-scoped to the caller's own rows).
  Stream<List<AppNotification>> watchMine() {
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(AppNotification.fromMap).toList());
  }

  /// Live unread count derived from [watchMine], for the home-screen badge.
  Stream<int> watchUnreadCount() {
    return watchMine().map(
        (notifications) => notifications.where((item) => !item.read).length);
  }
}
