import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/appointment_format.dart';
import 'package:sbtf_mobile/core/models/appointment.dart';

void main() {
  group('Appointment.fromMap', () {
    test('parses the columns the database defines', () {
      final appointment = Appointment.fromMap({
        'id': 'a-1',
        'application_id': 'app-1',
        'kind': 'evaluation',
        'status': 'scheduled',
        'scheduled_at': '2026-10-15T06:30:00Z',
        'venue': 'Franchising Office, Counter 2',
        'outcome': null,
        'notes': 'Bring your cedula.',
        'completed_at': null,
        'created_at': '2026-10-01T03:00:00Z',
      });

      expect(appointment.id, 'a-1');
      expect(appointment.applicationId, 'app-1');
      expect(appointment.kind, 'evaluation');
      expect(appointment.status, 'scheduled');
      expect(appointment.scheduledAt, DateTime.utc(2026, 10, 15, 6, 30));
      expect(appointment.venue, 'Franchising Office, Counter 2');
      expect(appointment.outcome, isNull);
      expect(appointment.notes, 'Bring your cedula.');
      expect(appointment.completedAt, isNull);
      expect(appointment.createdAt, DateTime.utc(2026, 10, 1, 3));
    });

    test('reads the joined application number', () {
      final appointment = Appointment.fromMap({
        'id': 'a-1',
        'application_id': 'app-1',
        'kind': 'hearing',
        'status': 'scheduled',
        'scheduled_at': '2026-10-15T06:30:00Z',
        'venue': 'Municipal Hall',
        'application': {
          'id': 'app-1',
          'application_number': 'APP-2026-0001',
        },
      });

      expect(appointment.applicationNumber, 'APP-2026-0001');
    });

    test('survives a row without the optional columns', () {
      final appointment = Appointment.fromMap({
        'id': 'a-1',
        'application_id': 'app-1',
        'kind': 'other',
        'status': 'scheduled',
        'scheduled_at': '2026-10-15T06:30:00Z',
        'venue': 'Municipal Hall',
      });

      expect(appointment.applicationNumber, isNull);
      expect(appointment.outcome, isNull);
      expect(appointment.notes, isNull);
      expect(appointment.createdAt, isNull);
      expect(appointment.kind, 'other');
    });

    test('falls back to a safe kind and status for an unknown row', () {
      final appointment = Appointment.fromMap({'id': 'a-1'});

      expect(appointment.kind, 'other');
      expect(appointment.status, 'scheduled');
      expect(appointment.venue, '');
    });
  });

  group('Appointment scheduling state', () {
    Appointment build({
      required String status,
      required DateTime scheduledAt,
    }) {
      return Appointment(
        id: 'a-1',
        applicationId: 'app-1',
        kind: 'evaluation',
        status: status,
        scheduledAt: scheduledAt,
        venue: 'Municipal Hall',
      );
    }

    test('a scheduled appointment in the future is upcoming', () {
      final appointment = build(
        status: 'scheduled',
        scheduledAt: DateTime.now().add(const Duration(days: 3)),
      );

      expect(appointment.stillStands, isTrue);
      expect(appointment.isUpcoming, isTrue);
    });

    test('a rescheduled appointment in the future is still upcoming', () {
      final appointment = build(
        status: 'rescheduled',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      );

      expect(appointment.stillStands, isTrue);
      expect(appointment.isUpcoming, isTrue);
    });

    test('a scheduled appointment in the past is not upcoming', () {
      final appointment = build(
        status: 'scheduled',
        scheduledAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(appointment.isUpcoming, isFalse);
    });

    test('a cancelled appointment is never upcoming', () {
      final appointment = build(
        status: 'cancelled',
        scheduledAt: DateTime.now().add(const Duration(days: 5)),
      );

      expect(appointment.stillStands, isFalse);
      expect(appointment.isUpcoming, isFalse);
    });

    test('a completed or missed appointment is never upcoming', () {
      for (final status in ['completed', 'no_show']) {
        final appointment = build(
          status: status,
          scheduledAt: DateTime.now().add(const Duration(days: 5)),
        );

        expect(appointment.stillStands, isFalse, reason: status);
        expect(appointment.isUpcoming, isFalse, reason: status);
      }
    });
  });

  group('Appointment.hasRemark', () {
    Appointment build({String? outcome}) {
      return Appointment(
        id: 'a-1',
        applicationId: 'app-1',
        kind: 'evaluation',
        status: 'completed',
        scheduledAt: DateTime.utc(2026, 10, 15, 6, 30),
        venue: 'Municipal Hall',
        outcome: outcome,
      );
    }

    test('is false without a recorded outcome', () {
      expect(build().hasRemark, isFalse);
    });

    test('is false for a blank outcome', () {
      expect(build(outcome: '   ').hasRemark, isFalse);
    });

    test('is true for a recorded outcome', () {
      expect(build(outcome: 'Documents verified.').hasRemark, isTrue);
    });
  });

  group('appointmentKindLabel', () {
    test('maps the known kinds to their web-console labels', () {
      expect(appointmentKindLabel('evaluation'), 'Evaluation');
      expect(
        appointmentKindLabel('physical_documents'),
        'Physical document submission',
      );
      expect(appointmentKindLabel('hearing'), 'Hearing');
      expect(appointmentKindLabel('release'), 'Document release');
      expect(appointmentKindLabel('other'), 'Other');
    });

    test('humanises a kind this build does not know yet', () {
      expect(appointmentKindLabel('site_visit'), 'Site Visit');
    });

    test('falls back gracefully for an empty kind', () {
      expect(appointmentKindLabel(''), 'Appointment');
    });

    test('every known kind has a label and no raw underscore', () {
      for (final entry in appointmentKindLabels.entries) {
        expect(appointmentKindLabel(entry.key), entry.value);
        expect(entry.value.contains('_'), isFalse);
      }
    });
  });

  group('appointmentStatusLabel', () {
    test('maps the known statuses to their web-console labels', () {
      expect(appointmentStatusLabel('scheduled'), 'Scheduled');
      expect(appointmentStatusLabel('completed'), 'Completed');
      expect(appointmentStatusLabel('no_show'), 'No show');
      expect(appointmentStatusLabel('rescheduled'), 'Rescheduled');
      expect(appointmentStatusLabel('cancelled'), 'Cancelled');
    });

    test('humanises a status this build does not know yet', () {
      expect(appointmentStatusLabel('postponed'), 'Postponed');
    });

    test('every known status has a label and no raw underscore', () {
      for (final entry in appointmentStatusLabels.entries) {
        expect(appointmentStatusLabel(entry.key), entry.value);
        expect(entry.value.contains('_'), isFalse);
      }
    });
  });

  group('appointmentDayLabel', () {
    final now = DateTime(2026, 10, 15, 9, 30);

    test('names today and tomorrow', () {
      expect(
        appointmentDayLabel(DateTime(2026, 10, 15, 14, 0), now: now),
        'Today',
      );
      expect(
        appointmentDayLabel(DateTime(2026, 10, 16, 9, 0), now: now),
        'Tomorrow',
      );
    });

    test('counts the days for the rest of the week', () {
      expect(
        appointmentDayLabel(DateTime(2026, 10, 19, 9, 0), now: now),
        'In 4 days',
      );
    });

    test('describes a recent day in the past', () {
      expect(
        appointmentDayLabel(DateTime(2026, 10, 14, 9, 0), now: now),
        'Yesterday',
      );
      expect(
        appointmentDayLabel(DateTime(2026, 10, 12, 9, 0), now: now),
        '3 days ago',
      );
    });

    test('says nothing once the day is more than a week away', () {
      expect(
        appointmentDayLabel(DateTime(2026, 10, 30, 9, 0), now: now),
        '',
      );
      expect(
        appointmentDayLabel(DateTime(2026, 9, 1, 9, 0), now: now),
        '',
      );
    });
  });
}
