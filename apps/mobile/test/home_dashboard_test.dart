import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Mabini Franchise'), findsOneWidget);
  });

  testWidgets('groups every destination under the section headers',
      (tester) async {
    await _pumpTall(tester, _harness(0));

    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Track & updates'), findsOneWidget);
    expect(find.text('New franchise application'), findsOneWidget);
    expect(find.text('Renewal application'), findsOneWidget);
    expect(find.text('My documents'), findsOneWidget);
    expect(find.text('Certificate & QR code'), findsOneWidget);
    expect(find.text('My application status'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('the notifications row carries the live unread badge',
      (tester) async {
    await _pumpTall(tester, _harness(3));

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('service cards use compact typography and spacing',
      (tester) async {
    await _pumpTall(tester, _harness(0));

    final title = tester.widget<Text>(find.text('My documents'));
    expect(title.style?.fontSize, 14);

    final cardFinder = find.ancestor(
      of: find.text('My documents'),
      matching: find.byType(Card),
    );
    final cardSize = tester.getSize(cardFinder);
    expect(cardSize.height, inInclusiveRange(48, 72));
  });
}
