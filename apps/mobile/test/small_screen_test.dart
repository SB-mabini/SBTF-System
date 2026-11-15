import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/env.dart';
import 'package:sbtf_mobile/features/auth/email_verification_screen.dart';
import 'package:sbtf_mobile/features/auth/forgot_password_screen.dart';
import 'package:sbtf_mobile/features/auth/login_screen.dart';
import 'package:sbtf_mobile/features/auth/registration_screen.dart';

/// Lays the screen out on a 320 dp phone with the largest accessibility text
/// setting (200%) and fails on any overflow or layout exception.
Future<void> pumpTight(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pump();

  expect(
    tester.takeException(),
    isNull,
    reason: '${screen.runtimeType} overflowed at 320 dp with 200% text',
  );
}

void main() {
  setUp(() => currentEnv = const Env(demoMode: true));
  tearDown(() => currentEnv = Env.fromEnvironment);

  testWidgets('sign-in fits a 320 dp phone at 200% text', (tester) async {
    await pumpTight(tester, const LoginScreen());
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Forgot your password?'), findsOneWidget);
  });

  testWidgets('registration fits a 320 dp phone at 200% text', (tester) async {
    await pumpTight(tester, const RegistrationScreen());
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('OTP screen fits a 320 dp phone at 200% text', (tester) async {
    await pumpTight(
      tester,
      const EmailVerificationScreen(
        email: 'juan@example.com',
        codeWasSent: false,
      ),
    );
    expect(find.text('Confirm your e-mail'), findsWidgets);
    expect(find.textContaining('Tap “Send a new code”'), findsOneWidget);
  });

  testWidgets('forgot-password fits a 320 dp phone at 200% text',
      (tester) async {
    await pumpTight(tester, const ForgotPasswordScreen());
    expect(find.text('Send reset code'), findsOneWidget);
  });
}
