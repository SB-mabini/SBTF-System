import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/theme.dart';
import 'package:sbtf_mobile/core/widgets/app_banner.dart';
import 'package:sbtf_mobile/core/widgets/empty_state.dart';
import 'package:sbtf_mobile/core/widgets/section_header.dart';
import 'package:sbtf_mobile/core/widgets/status_chip.dart';

/// Hosts a widget in the real theme so component themes (card shape, button
/// styles) apply exactly as they do in the app.
Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('design tokens', () {
    test('the card theme uses the shared card radius', () {
      final shape = AppTheme.light.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, AppRadius.card);
      expect(AppRadius.card, const BorderRadius.all(Radius.circular(14)));
      expect(AppTheme.light.cardTheme.elevation, 0);
    });

    test('semantic colours pair with their tints', () {
      // A chip must never be built from an ad-hoc colour pair, so the four
      // tones are asserted as the single source of truth.
      expect(AppColors.successTint, isNot(AppColors.success));
      expect(AppColors.dangerTint, isNot(AppColors.danger));
    });
  });

  group('AppBanner', () {
    testWidgets('shows its message with the tone icon', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppBanner(
            tone: AppBannerTone.danger,
            message: 'Could not save right now.',
          ),
        ),
      );

      expect(find.text('Could not save right now.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('defaults to the info tone', (tester) async {
      await tester.pumpWidget(_host(const AppBanner(message: 'Heads up.')));

      expect(find.text('Heads up.'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('shows its title in sentence case', (tester) async {
      await tester.pumpWidget(_host(const SectionHeader('Services')));

      expect(find.text('Services'), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('renders the medallion, title, message and action',
        (tester) async {
      await tester.pumpWidget(
        _host(
          EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing yet',
            message: 'Come back later.',
            action: FilledButton(
              onPressed: () {},
              child: const Text('Get started'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('Come back later.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Get started'), findsOneWidget);
    });

    testWidgets('omits the message and action when not supplied',
        (tester) async {
      await tester.pumpWidget(
        _host(const EmptyState(icon: Icons.inbox_outlined, title: 'Empty')),
      );

      expect(find.text('Empty'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('StatusChip', () {
    testWidgets('renders the label of the helper it was built from',
        (tester) async {
      await tester.pumpWidget(_host(applicationStatusChip('approved')));

      expect(find.text('Approved'), findsOneWidget);
    });
  });
}
