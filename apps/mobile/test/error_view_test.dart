import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/app_error.dart';
import 'package:sbtf_mobile/core/widgets/error_view.dart';

void main() {
  group('ErrorView', () {
    testWidgets('classifies a raw failure into a message, hint and retry',
        (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              error: Exception(
                  'SocketException: Failed host lookup: example.supabase.co'),
              onRetry: () => retried++,
            ),
          ),
        ),
      );

      expect(find.textContaining('Could not reach'), findsOneWidget);
      expect(find.textContaining('Wi-Fi'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('shows the message alone when the failure has no hint',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              error: const AppFailure(
                kind: AppFailureKind.businessRule,
                message: 'No file was selected.',
              ),
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('No file was selected.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // A business-rule failure is already specific, so no hint line is drawn.
      expect(find.textContaining('Try again'), findsNothing);
    });

    testWidgets('picks a distinct icon per failure kind', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              error: const AppFailure(
                kind: AppFailureKind.schemaMissing,
                message: 'The database is not ready.',
              ),
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.storage_outlined), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_outlined), findsNothing);
    });
  });

  group('CenteredScrollView', () {
    testWidgets('stays scrollable when its content fits', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CenteredScrollView(child: Text('nothing here')),
          ),
        ),
      );

      expect(find.text('nothing here'), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);
    });
  });
}
