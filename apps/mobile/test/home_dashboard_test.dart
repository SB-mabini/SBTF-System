import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/toda.dart';
import 'package:sbtf_mobile/core/models/profile.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/features/home/home_screen.dart';

const Profile _profile = Profile(
  id: 'user-1',
  role: 'driver',
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  email: 'juan@example.com',
);

/// Pumps onto a surface tall enough that the whole dashboard is laid out; the
/// default 800x600 window can leave the last rows unbuilt.
Future<void> _pumpTall(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(520, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Widget _harness(int unread) => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) => _profile),
        unreadNotificationCountStreamProvider
            .overrideWith((ref) => Stream.value(unread)),
        todaListProvider.overrideWith((ref) => const <Toda>[]),
        barangayListProvider.overrideWith((ref) => const <Barangay>[]),
        openFormRequestProvider.overrideWith((ref) => Future.value(null)),
        latestRejectedFormRequestProvider
            .overrideWith((ref) => Future.value(null)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  testWidgets('greets the signed-in driver in the hero card', (tester) async {
    await _pumpTall(tester, _harness(0));

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('JD'), findsOneWidget);
    expect(find.text('juan@example.com'), findsOneWidget);
    expect(find.text('Driver / Operator'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('SBTF System'), findsOneWidget);
  });

  testWidgets('keeps destinations on the Track and Documents tabs',
      (tester) async {
    await _pumpTall(tester, _harness(0));

    await tester.tap(find.text('Track'));
    await tester.pumpAndSettle();

    expect(find.text('Track & Updates'), findsOneWidget);
    expect(find.text('My Appointments'), findsOneWidget);
    expect(find.text('My Application Status'), findsOneWidget);
    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    expect(find.text('Documents & Certificates'), findsOneWidget);
    expect(find.text('My Documents'), findsOneWidget);
    expect(find.text('Certificate & QR Code'), findsOneWidget);
  });

  testWidgets('the notifications row carries the live unread badge',
      (tester) async {
    await _pumpTall(tester, _harness(3));

    await tester.tap(find.text('Track'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('service cards use compact typography and spacing',
      (tester) async {
    await _pumpTall(tester, _harness(0));

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('My Documents'));
    expect(title.style?.fontSize, 15);

    final cardFinder = find.ancestor(
      of: find.text('My Documents'),
      matching: find.byType(Card),
    );
    final cardSize = tester.getSize(cardFinder);
    expect(cardSize.height, inInclusiveRange(48, 80));
  });

  testWidgets('Apply navigation opens the request form first', (tester) async {
    await _pumpTall(tester, _harness(0));

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Request form'), findsOneWidget);
    expect(find.text('Submit request'), findsOneWidget);
    expect(find.text('New application'), findsNothing);
    expect(find.text('Apply for Franchise'), findsNothing);
  });
}
