/// Notification presentation helpers — slice 7.
///
/// Mirrors the web console's `components/notifications/notification-list.tsx`
/// so a given `public.notification_type` reads the same on both clients. Pure
/// and dependency-free, so it is trivially unit-testable.
library;

/// Human-readable labels for the `public.notification_type` values the database
/// defines today.
const Map<String, String> notificationTypeLabels = {
  'application_submitted': 'Application submitted',
  'application_approved': 'Application approved',
  'application_rejected': 'Application rejected',
  'document_verified': 'Document verified',
  'document_rejected': 'Document rejected',
  'renewal_reminder': 'Renewal reminder',
  'application_under_review': 'Application under review',
  'appointment_scheduled': 'Appointment scheduled',
  'appointment_updated': 'Appointment updated',
  'form_request_received': 'Form request received',
  'form_request_issued': 'Form request approved',
  'form_request_rejected': 'Form request returned',
  'form_request_resubmitted': 'Form request resubmitted',
  'form_request_review_reminder': 'Form request review due',
  'form_request_review_overdue': 'Form request review overdue',
  'account_updated': 'Account updated',
  'system': 'System',
};

/// The label for [type], or a humanised fallback for a value this build does not
/// know yet.
///
/// The enum can gain members on the server before the app is rebuilt; falling
/// back to "Application Under Review" beats showing a raw `snake_case` key.
String notificationTypeLabel(String type) {
  final known = notificationTypeLabels[type];
  if (known != null) return known;

  final words = type
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .toList();
  return words.isEmpty ? 'Notification' : words.join(' ');
}
