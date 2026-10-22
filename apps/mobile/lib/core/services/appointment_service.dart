import '../models/appointment.dart';
import 'service_base.dart';

/// In-person appointments — slice 9.
///
/// Appointments are booked by the municipal staff from the web console
/// (`rpc_staff_schedule_appointment`) and the table is **read-only to
/// clients**: `grant select` is all the table carries, and every write moves
/// through a staff RPC. This service therefore only reads.
///
/// RLS ("appointments: drivers read their own appointments") restricts every
/// query below to the appointments of the caller's own applications, so the
/// list can never show another driver's schedule.
class AppointmentService extends SupabaseService {
  AppointmentService(super.client);

  /// Columns selected for a row: the appointment plus the number of the
  /// application it belongs to.
  ///
  /// The join is spelled with its foreign key so PostgREST cannot guess the
  /// relationship, exactly as the web console does.
  static const String _select = '*, application:franchise_applications!'
      'application_appointments_application_id_fkey(id, application_number)';

  /// The caller's own appointments, soonest first.
  Future<List<Appointment>> listMine() {
    return guard(() async {
      final rows = await client
          .from('application_appointments')
          .select(_select)
          .order('scheduled_at');
      return rows
          .map((row) =>
              Appointment.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// One appointment by id, or null when it does not exist / is not the
  /// caller's.
  ///
  /// Used to resolve a notification's deep link: the row is re-read by id, so
  /// a stale link can only ever resolve to the caller's own appointment.
  Future<Appointment?> getById(String id) {
    return guard(() async {
      final row = await client
          .from('application_appointments')
          .select(_select)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return Appointment.fromMap(Map<String, dynamic>.from(row));
    });
  }

  /// Live list of the caller's appointments (RLS-scoped to their own rows).
  ///
  /// A Realtime change event carries only the changed row's own columns — the
  /// joined application number is missing — so the stream re-reads the joined
  /// list whenever the server reports a change. That keeps a newly scheduled
  /// appointment reaching the driver's phone without a manual refresh.
  Stream<List<Appointment>> watchMine() {
    return client
        .from('application_appointments')
        .stream(primaryKey: ['id'])
        .order('scheduled_at')
        .asyncMap((_) => listMine());
  }
}
