import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/env.dart';
import 'package:sbtf_mobile/features/auth/login_screen.dart';

void main() {
  tearDown(() {
    currentEnv = Env.fromEnvironment;
  });

  testWidgets('demo mode keeps the form visible but disabled', (tester) async {
    currentEnv = const Env(demoMode: true);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // The banner explains why sign-in is disabled — the form is never hidden.
    expect(find.textContaining('Preview mode'), findsOneWidget);

    final emailField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(emailField.enabled, isFalse);

    final signIn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(signIn.onPressed, isNull);

    final register = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(register.onPressed, isNull);
  });
}
