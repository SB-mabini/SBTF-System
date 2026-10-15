/// One entry in an application's immutable timeline
/// (`public.application_status_history`).
///
/// The table is written by SECURITY DEFINER functions only; drivers read the
/// entries that concern their own applications.
class ApplicationEvent {
  const ApplicationEvent({
    required this.id,
    required this.applicationId,
    required this.event,
    this.actorId,
    this.note,
    this.createdAt,
  });

  final String id;
  final String applicationId;

  /// Matches `public.application_event`: created, document_uploaded,
  /// document_replaced, document_verified, document_rejected, review_started,
  /// approved, rejected, certificate_issued, archived.
  final String event;

  final String? actorId;
  final String? note;
  final DateTime? createdAt;

  /// Human-readable description of the event, used by the status tracker
  /// (slice 4).
  String get label {
    switch (event) {
      case 'created':
        return 'Application submitted';
      case 'document_uploaded':
        return 'Document uploaded';
      case 'document_replaced':
        return 'Document replaced';
      case 'document_verified':
        return 'Document verified';
      case 'document_rejected':
        return 'Document rejected';
      case 'review_started':
        return 'Review started';
      case 'approved':
        return 'Application approved';
      case 'rejected':
        return 'Application rejected';
      case 'certificate_issued':
        return 'Certificate issued';
      case 'archived':
        return 'Franchise archived';
      default:
        return event.replaceAll('_', ' ');
    }
  }

  factory ApplicationEvent.fromMap(Map<String, dynamic> map) {
    return ApplicationEvent(
      id: (map['id'] ?? '').toString(),
      applicationId: (map['application_id'] ?? '').toString(),
      event: (map['event'] ?? '').toString(),
      actorId: map['actor_id']?.toString(),
      note: map['note']?.toString(),
      createdAt: _asDate(map['created_at']),
    );
  }
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
