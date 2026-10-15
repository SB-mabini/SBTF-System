/// An in-app notification (`public.notifications`).
///
/// Named `AppNotification` so it never collides with Flutter's `Notification`
/// widget/base class. Drivers read, mark as read and delete only their own rows.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.targetType,
    this.targetId,
    this.read = false,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String message;

  /// Matches `public.notification_type`: application_submitted,
  /// application_approved, application_rejected, document_verified,
  /// document_rejected, renewal_reminder, application_under_review,
  /// account_updated, system.
  final String notificationType;

  /// Optional deep-link target (`public.log_target_type`) and its row id.
  final String? targetType;
  final String? targetId;

  final bool read;
  final DateTime? readAt;
  final DateTime? createdAt;

  /// True when the notification points at a franchise application the app can
  /// open from the notifications list.
  bool get targetsApplication =>
      targetType == 'franchise_application' && targetId != null;

  /// True when it points at an issued franchise record (certificate).
  bool get targetsRecord =>
      targetType == 'franchise_record' && targetId != null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      notificationType: (map['notification_type'] ?? 'system').toString(),
      targetType: map['target_type']?.toString(),
      targetId: map['target_id']?.toString(),
      read: map['read'] == true,
      readAt: _asDate(map['read_at']),
      createdAt: _asDate(map['created_at']),
    );
  }
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
