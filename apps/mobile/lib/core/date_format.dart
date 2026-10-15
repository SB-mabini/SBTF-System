/// Dependency-free date/time formatting for the driver-facing screens.
///
/// The app deliberately does not depend on `intl`: the only formats it needs
/// are these, and keeping them pure makes them trivially testable. Every value
/// is rendered in the device's local time, because a driver reasons about
/// "when" in their own day. A missing date renders as an em dash rather than an
/// empty cell, so a table row never collapses.
library;

const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// e.g. `15 Oct 2026`, or `—` when [value] is null.
String formatDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.day} ${_monthAbbreviations[local.month - 1]} ${local.year}';
}

/// e.g. `15 Oct 2026, 2:30 PM`, or `—` when [value] is null.
String formatDateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${formatDate(local)}, $hour:$minute $period';
}
