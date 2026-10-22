/// An in-person appointment (`public.application_appointments`).
///
/// Appointments are scheduled by the municipal staff from the web console
/// (`rpc_staff_schedule_appointment`) and are **read-only to clients**: the
/// table grants `select` only, and every write moves through a staff RPC. This
/// app therefore never writes an appointment — it only shows what the office
/// has arranged.
///
/// RLS ("appointments: drivers read their own appointments") limits a driver
/// to the appointments of their own applications, so the query behind this
/// model cannot leak another account's schedule.
class Appointment {
  const Appointment({
    required this.id,
    required this.applicationId,
    required this.kind,
    required this.status,
    required this.scheduledAt,
    required this.venue,
    this.outcome,
    this.notes,
    this.completedAt,
    this.createdAt,
    this.applicationNumber,
  });

  final String id;

  /// The application this appointment belongs to.
  final String applicationId;

  /// Matches `public.appointment_kind`:
  /// `evaluation` | `physical_documents` | `hearing` | `release` | `other`.
  final String kind;

  /// Matches `public.appointment_status`:
  /// `scheduled` | `completed` | `no_show` | `rescheduled` | `cancelled`.
  final String status;

  /// When the appointment is meant to happen, in UTC.
  final DateTime scheduledAt;

  /// Where the driver has to go — the municipal office, a counter, a room.
  final String venue;

  /// What the office recorded when the appointment was closed out.
  final String? outcome;

  /// A note from the office, shown to the driver.
  final String? notes;

  /// When the appointment was closed out (`completed` or `no_show`).
  final DateTime? completedAt;

  /// When the appointment was booked.
  final DateTime? createdAt;

  /// The owning application's number, present when the query joins it.
  final String? applicationNumber;

  /// True while the appointment is still something to attend: the status is
  /// `scheduled` or `rescheduled` — the office moved the time but the visit
  /// still stands — and the date has not passed.
  bool get isUpcoming {
    if (!stillStands) return false;
    return scheduledAt.isAfter(DateTime.now());
  }

  /// True while the appointment has not been closed out or called off.
  bool get stillStands => status == 'scheduled' || status == 'rescheduled';

  /// True when the office recorded an outcome or a note for the driver.
  bool get hasRemark => (outcome ?? '').trim().isNotEmpty;

  factory Appointment.fromMap(Map<String, dynamic> map) {
    final application = map['application'] ?? map['franchise_applications'];

    return Appointment(
      id: (map['id'] ?? '').toString(),
      applicationId: (map['application_id'] ?? '').toString(),
      kind: (map['kind'] ?? 'other').toString(),
      status: (map['status'] ?? 'scheduled').toString(),
      scheduledAt: _asDate(map['scheduled_at']) ?? DateTime.now(),
      venue: (map['venue'] ?? '').toString(),
      outcome: map['outcome']?.toString(),
      notes: map['notes']?.toString(),
      completedAt: _asDate(map['completed_at']),
      createdAt: _asDate(map['created_at']),
      applicationNumber: application is Map
          ? application['application_number']?.toString()
          : null,
    );
  }
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
