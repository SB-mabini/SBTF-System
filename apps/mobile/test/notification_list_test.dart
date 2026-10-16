import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/app_notification.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';
import 'package:sbtf_mobile/core/models/franchise_record.dart';
import 'package:sbtf_mobile/core/models/profile.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/core/services/application_service.dart';
import 'package:sbtf_mobile/core/services/certificate_service.dart';
import 'package:sbtf_mobile/core/services/notification_service.dart';
import 'package:sbtf_mobile/features/application/application_detail_screen.dart';
import 'package:sbtf_mobile/features/certificate/certificate_detail_screen.dart';
import 'package:sbtf_mobile/features/home/home_screen.dart';
import 'package:sbtf_mobile/features/notifications/notification_list_screen.dart';

AppNotification _notification({
  required String id,
  String title = 'Your application was approved',
  String message = 'The municipal office approved your application.',
  String type = 'application_approved',
  String? targetType,
  String? targetId,
  bool read = false,
  DateTime? createdAt,
}) {
  return AppNotification(
    id: id,
    userId: 'user-1',
    title: title,
    message: message,
    notificationType: type,
    targetType: targetType,
    targetId: targetId,
    read: read,
    readAt: read ? DateTime(2026, 9, 2) : null,
    createdAt: createdAt ?? DateTime(2026, 9, 1),
  );
}

FranchiseApplication _application() {
  return FranchiseApplication.fromMap({
    'id': 'app-1',
    'application_number': 'SBTF-2026-0001',
    'status': 'approved',
    'submitted_at': '2026-09-01T00:00:00Z',
  });
}

FranchiseRecord _record() {
  return FranchiseRecord(
    id: 'rec-1',
    applicationId: 'app-1',
    operatorId: 'op-1',
    todaId: 'toda-1',
    franchiseNumber: 'SBTF-2026-0001',
    verificationCode: 'ABCDEFGHJKLM',
    issuedAt: DateTime(2026, 1, 1),
    expiresAt: DateTime.now().add(const Duration(days: 400)),
    archived: false,
    todaName: 'Mabini TODA',
    plateNumber: 'ABC 1234',
    operatorName: 'Juan Dela Cruz',
  );
}

const Profile _profile = Profile(
  id: 'user-1',
  role: 'driver',
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  email: 'juan@example.com',
);

/// A stand-in for [NotificationService].
///
/// It deliberately does not extend the real service: constructing that builds a
/// `SupabaseClient`, whose background auth-refresh timer a widget test reports
/// as a leak. Only the members the screens touch are implemented; anything else
/// fails loudly through [noSuchMethod].
class _FakeNotificationService implements NotificationService {
  _FakeNotificationService(this.notifications);

  final List<AppNotification> notifications;
  final List<String> readIds = <String>[];
  int markAllCalls = 0;
  final List<String> deletedIds = <String>[];
  int deleteReadCalls = 0;

  @override
  Stream<List<AppNotification>> watchMine() => Stream.value(notifications);

  @override
  Future<void> markRead(String id) async => readIds.add(id);

  @override
  Future<void> markAllRead() async => markAllCalls++;

  @override
  Future<void> delete(String id) async => deletedIds.add(id);

  @override
  Future<void> deleteRead() async => deleteReadCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call to ${invocation.memberName}');
}

class _FakeApplicationService implements ApplicationService {
  _FakeApplicationService(this.application);

  final FranchiseApplication? application;

  @override
  Future<FranchiseApplication?> getById(String id) async => application;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call to ${invocation.memberName}');
}

class _FakeCertificateService implements CertificateService {
  _FakeCertificateService(this.record);

  final FranchiseRecord? record;

  @override
  Future<FranchiseRecord?> getById(String id) async => record;

  @override
  Future<String?> verificationBaseUrl() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call to ${invocation.memberName}');
}

Widget _harness({
  required Widget home,
  NotificationService? notifications,
  ApplicationService? applications,
  CertificateService? certificates,
  FranchiseApplication? detail,
}) {
  return ProviderScope(
    overrides: [
      if (notifications != null)
        notificationServiceProvider.overrideWith((ref) => notifications),
      if (applications != null)
        applicationServiceProvider.overrideWith((ref) => applications),
      if (certificates != null)
        certificateServiceProvider.overrideWith((ref) => certificates),
      if (detail != null)
        applicationDetailProvider.overrideWith((ref, id) => detail),
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
  group('notification list', () {
    testWidgets('lists each notification with its type label and unread badge',
        (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const NotificationListScreen(),
          notifications: _FakeNotificationService([
            _notification(
              id: 'n1',
              title: 'Your franchise is ready',
              type: 'application_approved',
            ),
            _notification(
              id: 'n2',
              title: 'Renewal due soon',
              type: 'renewal_reminder',
              read: true,
            ),
          ]),
        ),
      );

      expect(find.text('Your franchise is ready'), findsOneWidget);
      expect(find.text('Renewal due soon'), findsOneWidget);
      // Type chip labels come from the shared web-parity vocabulary.
      expect(find.text('Application approved'), findsOneWidget);
      expect(find.text('Renewal reminder'), findsOneWidget);
      // Only the unread row carries the "New" badge.
      expect(find.text('New'), findsOneWidget);
      expect(find.text('1 unread notification.'), findsOneWidget);
    });

    testWidgets('an empty feed explains what will appear here', (tester) async {
      await _pump(
        tester,
        _harness(
          home: const NotificationListScreen(),
          notifications: _FakeNotificationService(const []),
        ),
      );

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.text('Everything has been read.'), findsNothing);
    });

    testWidgets('appointment notification card uses compact spacing and text',
        (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const NotificationListScreen(),
          notifications: _FakeNotificationService([
            _notification(
              id: 'appointment-1',
              title: 'Appointment scheduled',
              message: 'A hearing appointment is set for Oct 19 at 1:00 PM.',
              type: 'system',
            ),
          ]),
        ),
      );

      final title = find.text('Appointment scheduled');
      final message =
          find.text('A hearing appointment is set for Oct 19 at 1:00 PM.');
      final card = find.ancestor(of: title, matching: find.byType(Card));

      expect(tester.widget<Text>(title).style?.fontSize, 13);
      expect(tester.widget<Text>(message).style?.fontSize, 12);
      expect(tester.getSize(card).height, lessThan(125));
    });

    testWidgets('tapping an unread notification marks it read', (tester) async {
      final service = _FakeNotificationService([
        _notification(
            id: 'n1', title: 'Renewal due soon', type: 'renewal_reminder'),
      ]);

      await _pump(
        tester,
        _harness(home: const NotificationListScreen(), notifications: service),
      );

      await tester.tap(find.text('Renewal due soon'));
      await tester.pumpAndSettle();

      expect(service.readIds, ['n1']);
    });

    testWidgets('mark all as read uses the bulk update', (tester) async {
      final service = _FakeNotificationService([
        _notification(id: 'n1'),
        _notification(id: 'n2'),
      ]);

      await _pump(
        tester,
        _harness(home: const NotificationListScreen(), notifications: service),
      );

      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();

      expect(service.markAllCalls, 1);
      expect(find.text('All notifications marked as read.'), findsOneWidget);
    });

    testWidgets('the mark-all action is disabled when nothing is unread',
        (tester) async {
      await _pump(
        tester,
        _harness(
          home: const NotificationListScreen(),
          notifications: _FakeNotificationService([
            _notification(id: 'n1', read: true),
          ]),
        ),
      );

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.done_all),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Everything has been read.'), findsOneWidget);
    });

    testWidgets('tapping an application notification opens its tracker',
        (tester) async {
      final application = _application();
      final service = _FakeNotificationService([
        _notification(
          id: 'n1',
          title: 'Decision ready',
          targetType: 'franchise_application',
          targetId: 'app-1',
        ),
      ]);

      await _pumpTall(
        tester,
        _harness(
          home: const NotificationListScreen(),
          notifications: service,
          applications: _FakeApplicationService(application),
          detail: application,
        ),
      );

      await tester.tap(find.text('Decision ready'));
      await tester.pumpAndSettle();

      expect(find.byType(ApplicationDetailScreen), findsOneWidget);
      expect(service.readIds, ['n1']);
    });

    testWidgets('tapping a record notification opens its certificate',
        (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const NotificationListScreen(),
          notifications: _FakeNotificationService([
            _notification(
              id: 'n1',
              title: 'Certificate issued',
              targetType: 'franchise_record',
              targetId: 'rec-1',
            ),
          ]),
          certificates: _FakeCertificateService(_record()),
        ),
      );

      await tester.tap(find.text('Certificate issued'));
      await tester.pumpAndSettle();

      expect(find.byType(CertificateDetailScreen), findsOneWidget);
    });

    testWidgets('a notification whose target is gone says so', (tester) async {
      await _pump(
        tester,
        _harness(
          home: const NotificationListScreen(),
          notifications: _FakeNotificationService([
            _notification(
              id: 'n1',
              title: 'Decision ready',
              targetType: 'franchise_application',
              targetId: 'gone',
            ),
          ]),
          applications: _FakeApplicationService(null),
        ),
      );

      await tester.tap(find.text('Decision ready'));
      await tester.pumpAndSettle();

      expect(find.text('That application is no longer available.'),
          findsOneWidget);
      expect(find.byType(ApplicationDetailScreen), findsNothing);
    });

    testWidgets('long-pressing a notification confirms first, then removes it',
        (tester) async {
      final service = _FakeNotificationService([
        _notification(id: 'n1', title: 'Renewal due soon'),
      ]);

      await _pumpTall(
        tester,
        _harness(home: const NotificationListScreen(), notifications: service),
      );

      await tester.longPress(find.text('Renewal due soon'));
      await tester.pumpAndSettle();

      // A confirm stands between the gesture and the delete.
      expect(
        find.text('Delete Notification'),
        findsOneWidget,
      );
      expect(
        find.text('Are you sure you want to delete this notification?'),
        findsOneWidget,
      );
      expect(service.deletedIds, isEmpty);
      final dialogSurface = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Material),
      );
      final dialogSize = tester.getSize(dialogSurface.last);
      expect(dialogSize.width, lessThanOrEqualTo(320));
      expect(dialogSize.height, lessThanOrEqualTo(220));

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(service.deletedIds, ['n1']);
      expect(find.text('Notification deleted.'), findsOneWidget);
    });

    testWidgets('cancelling the delete dialog keeps the notification',
        (tester) async {
      final service = _FakeNotificationService([
        _notification(id: 'n1', title: 'Renewal due soon'),
      ]);

      await _pumpTall(
        tester,
        _harness(home: const NotificationListScreen(), notifications: service),
      );

      await tester.longPress(find.text('Renewal due soon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.deletedIds, isEmpty);
      expect(
        find.text('Delete Notification'),
        findsNothing,
      );
    });

    testWidgets('clear read removes the already-read notifications',
        (tester) async {
      final service = _FakeNotificationService([
        _notification(id: 'n1', title: 'Unread one'),
        _notification(id: 'n2', title: 'Read one', read: true),
      ]);

      await _pumpTall(
        tester,
        _harness(home: const NotificationListScreen(), notifications: service),
      );

      await tester.tap(find.byTooltip('Clear read notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Clear read notifications?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(service.deleteReadCalls, 1);
      expect(find.text('Read notifications cleared.'), findsOneWidget);
    });

    testWidgets('the clear-read action is disabled when nothing is read',
        (tester) async {
      await _pumpTall(
        tester,
        _harness(
          home: const NotificationListScreen(),
          notifications: _FakeNotificationService([
            _notification(id: 'n1'),
          ]),
        ),
      );

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_sweep_outlined),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('home notifications tile', () {
    Widget homeHarness(Stream<int> unread) {
      return ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => _profile),
          unreadNotificationCountStreamProvider.overrideWith((ref) => unread),
        ],
        child: const MaterialApp(home: HomeScreen()),
      );
    }

    testWidgets('shows the live unread count', (tester) async {
      await _pumpTall(tester, homeHarness(Stream.value(3)));

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides the badge when nothing is unread', (tester) async {
      await _pumpTall(tester, homeHarness(Stream.value(0)));

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('caps a large unread count', (tester) async {
      await _pumpTall(tester, homeHarness(Stream.value(42)));

      expect(find.text('9+'), findsOneWidget);
    });
  });
}
