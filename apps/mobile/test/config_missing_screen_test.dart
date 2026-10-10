import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/app/config_missing_screen.dart';
import 'package:sbtf_mobile/core/env.dart';

void main() {
  testWidgets('explains the missing configuration and prints the run command',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ConfigMissingScreen()),
    );

    expect(find.text('Configuration required'), findsOneWidget);
    expect(find.text('Supabase is not configured'), findsOneWidget);

    // The exact run command is shown so it can be copied.
    expect(find.textContaining('--dart-define=SUPABASE_URL'), findsOneWidget);
    expect(
        find.textContaining('--dart-define=SUPABASE_ANON_KEY'), findsOneWidget);

    expect(find.text('Copy run command'), findsOneWidget);
  });

  test('runCommand matches what the screen advertises', () {
    expect(runCommand, contains('flutter run'));
    expect(runCommand, contains('--dart-define'));
  });
}
