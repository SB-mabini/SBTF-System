/// Appointment presentation helpers — slice 9.
///
/// Mirrors the web console's `APPOINTMENT_KIND_LABELS` and
/// `APPOINTMENT_STATUS_LABELS` (`apps/web/src/lib/constants.ts`) so a given
/// `public.appointment_kind` or `public.appointment_status` reads the same on
/// both clients. Pure and dependency-free, so it is trivially unit-testable.
library;

/// Human-readable labels for the `public.appointment_kind` values the database
/// defines today.
const Map<String, String> appointmentKindLabels = {
  'evaluation': 'Evaluation',
  'physical_documents': 'Physical document submission',
  'hearing': 'Hearing',
  'release': 'Document release',
  'other': 'Other',
};

/// Human-readable labels for the `public.appointment_status` values the
/// database defines today.
const Map<String, String> appointmentStatusLabels = {
  'scheduled': 'Scheduled',
  'completed': 'Completed',
  'no_show': 'No show',
  'rescheduled': 'Rescheduled',
  'cancelled': 'Cancelled',
};

/// The label for [kind], or a humanised fallback for a value this build does
/// not know yet.
///
/// The enum can gain members on the server before the app is rebuilt; falling
/// back to "Physical Documents" beats showing a raw `snake_case` key.
String appointmentKindLabel(String kind) {
  final known = appointmentKindLabels[kind];
  if (known != null) return known;
  return _humanise(kind, fallback: 'Appointment');
}

/// The label for [status], or a humanised fallback for a value this build does
/// not know yet.
String appointmentStatusLabel(String status) {
  final known = appointmentStatusLabels[status];
  if (known != null) return known;
  return _humanise(status, fallback: 'Appointment');
}

/// A short, driver-facing sense of *when* an appointment falls.
///
/// "Today", "Tomorrow" and "In 4 days" are what a driver needs at a glance;
/// anything further out keeps the plain date, which the card shows anyway.
/// [now] is injectable so the label is testable without a fake clock.
String appointmentDayLabel(DateTime scheduledAt, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final day = _dateOnly(scheduledAt);
  final difference = day.difference(today).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  if (difference > 1 && difference < 7) return 'In $difference days';
  if (difference == -1) return 'Yesterday';
  if (difference < -1 && difference > -7) {
    final days = difference.abs();
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
  return '';
}

/// The day an appointment falls on, without the time of day.
DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _humanise(String value, {required String fallback}) {
  final words = value
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .toList();
  return words.isEmpty ? fallback : words.join(' ');
}
