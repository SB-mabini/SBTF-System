import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/appointment.dart';
import 'package:sbtf_mobile/core/models/profile.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/core/services/appointment_service.dart';
import 'package:sbtf_mobile/features/appointments/appointment_detail_screen.dart';
import 'package:sbtf_mobile/features/appointments/appointment_list_screen.dart';
import 'package:sbtf_mobile/features/home/home_screen.dart';

/// An appointment a few days out, still standing.
Appointment _upcoming({
  String id = 'a-1',
  String kind = 'evaluation',
  DateTime? scheduledAt,
  String venue = 'Franchising Office, Counter 2',
  String? applicationNumber = 'SBTF-2026-0001',
}) {
  return Appointment(
    id: id,
    applicationId: 'app-1',
    kind: kind,
    status: 'scheduled',
    scheduledAt: scheduledAt ?? DateTime.now().add(const Duration(days: 3)),
    venue: venue,
    applicationNumber: applicationNumber,
  );
}

/// An appointment that has been closed out.
Appointment _past({
  String id = 'a-2',
  String status = 'completed',
  String? outcome,
}) {
  return Appointment(
    id: id,
    applicationId: 'app-1',
    kind: 'hearing',
    status: status,
    scheduledAt: DateTime.now().subtract(const Duration(days: 2)),
    venue: 'Municipal Hall',
    outcome: outcome,
  );
}

const Profile _profile = Profile(
  id: 'user-1',
  role: 'driver',
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  email: 'juan@example.com',
);

/// A stand-in for [AppointmentService].
///
/// It deliberately does not extend the real service: constructing that builds a
/// `SupabaseClient`, whose background auth-refresh timer a widget test reports
/// as a leak. Only the members the screens touch are implemented; anything else
/// fails loudly through [noSuchMethod].
class _FakeAppointmentService implements AppointmentService {
  _FakeAppointmentService(this.appointments);

  final List<Appointment> appointments;

  @override
  Stream<List<Appointment>> watchMine() => Stream.value(appointments);

  @override
  Future<Appointment?> getById(String id) async {
    for (final appointment in appointments) {
      if (appointment.id == id) return appointment;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call to ${invocation.memberName}');
}

Widget _harness({
  required Widget home,
  AppointmentService? appointments,
}) {
  return ProviderScope(
    overrides: [
      if (appointments != null)
        appointmentServiceProvider.overrideWith((ref) => appointments),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// Pumps onto a surface tall enough that every tile/card is laid out; the
/// default 800x600 window can leave the last ones unbuilt.
Future<void> _pumpTall(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(520, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  group('appointment list', () {
    testWidgets('lists an upcoming appointment with its details',
        (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const AppointmentListScreen(),
          appointments: _FakeAppointmentService([_upcoming()]),
        ),
      );

      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('Evaluation'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Franchising Office, Counter 2'), findsOneWidget);
      expect(find.text('SBTF-2026-0001'), findsOneWidget);
      expect(find.text('1 upcoming appointment.'), findsOneWidget);
    });

    testWidgets('a past appointment waits behind the past tab', (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const AppointmentListScreen(),
          appointments: _FakeAppointmentService([_past()]),
        ),
      );

      // The upcoming scope is the default and holds nothing.
      expect(find.text('No upcoming appointments'), findsOneWidget);
      expect(find.text('Hearing'), findsNothing);

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();

      expect(find.text('Hearing'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('1 past visit.'), findsOneWidget);
    });

    testWidgets('a cancelled appointment is not counted as upcoming',
        (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const AppointmentListScreen(),
          appointments: _FakeAppointmentService([
            _past(status: 'cancelled'),
          ]),
        ),
      );

      expect(find.text('No upcoming appointments'), findsOneWidget);

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('an empty schedule explains what will appear here',
        (tester) async {
      await _pump(
        tester,
        _harness(
          home: const AppointmentListScreen(),
          appointments: _FakeAppointmentService(const []),
        ),
      );

      expect(find.text('No upcoming appointments'), findsOneWidget);
      expect(find.text('Check my application'), findsOneWidget);
    });

    testWidgets('tapping an appointment opens its detail', (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const AppointmentListScreen(),
          appointments: _FakeAppointmentService([_upcoming()]),
        ),
      );

      await tester.tap(find.text('Evaluation'));
      await tester.pumpAndSettle();

      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      expect(find.text('Date and time'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
    });

    testWidgets('the detail shows the outcome the office recorded',
        (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const AppointmentListScreen(),
          appointments: _FakeAppointmentService([
            _past(outcome: 'Documents verified and accepted.'),
          ]),
        ),
      );

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hearing'));
      await tester.pumpAndSettle();

      expect(find.text('Outcome'), findsOneWidget);
      expect(find.text('Documents verified and accepted.'), findsOneWidget);
    });
  });

  group('home appointments tile', () {
    Widget homeHarness(Stream<List<Appointment>> appointments) {
      return ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => _profile),
          myAppointmentsStreamProvider.overrideWith((ref) => appointments),
        ],
        child: const MaterialApp(home: HomeScreen()),
      );
    }

    testWidgets('shows the number of appointments still to attend',
        (tester) async {
      await _pumpTall(
        tester,
        homeHarness(Stream.value([_upcoming(), _upcoming(id: 'a-9')])),
      );

      expect(find.text('My appointments'), findsOneWidget);
      expect(find.text('Scheduled visits and hearings'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('hides the badge when nothing is upcoming', (tester) async {
      await _pumpTall(
        tester,
        homeHarness(Stream.value([_past()])),
      );

      expect(find.text('My appointments'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });
}
