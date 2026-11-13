import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/branding.dart';
import 'package:sbtf_mobile/core/onboarding/language.dart';
import 'package:sbtf_mobile/core/onboarding/onboarding_state.dart';
import 'package:sbtf_mobile/core/onboarding/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('OnboardingState', () {
    test('a fresh install needs onboarding at the welcome page', () {
      const state = OnboardingState.initial;
      expect(state.completed, isFalse);
      expect(state.needsOnboarding, isTrue);
      expect(state.resumeStep, OnboardingStep.welcome);
      expect(state.languageCode, AppLanguages.fallbackCode);
    });

    test('an outdated agreement resumes directly at the agreement', () {
      final state = OnboardingState(
        completed: true,
        step: OnboardingStep.finished,
        agreementVersion: '0.9',
        agreementAcceptedAt: DateTime.utc(2025),
      );

      expect(state.agreementIsCurrent, isFalse);
      expect(state.needsOnboarding, isTrue);
      expect(state.resumeStep, OnboardingStep.agreement);
    });

    test('a completed, current user skips onboarding', () {
      final state = OnboardingState(
        completed: true,
        step: OnboardingStep.finished,
        agreementVersion: AppBranding.agreementVersion,
        agreementAcceptedAt: DateTime.utc(2026, 11, 12),
      );

      expect(state.needsOnboarding, isFalse);
      expect(state.resumeStep, OnboardingStep.finished);
    });

    test('an unsupported language falls back to English', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        OnboardingState.keyLanguage: 'xx',
        OnboardingState.keyCompleted: true,
      });

      final store = OnboardingStore();
      final state = await store.load();

      expect(state.languageCode, 'en');
    });
  });

  group('OnboardingStore', () {
    test('persists completion, language and agreement acceptance', () async {
      final store = OnboardingStore();
      await store.load();

      await store.setLanguage('en');
      await store.acceptAgreement(
        acceptedAt: DateTime.utc(2026, 11, 12, 9, 30),
      );
      await store.complete();

      final reloaded = await OnboardingStore().load();
      expect(reloaded.completed, isTrue);
      expect(reloaded.step, OnboardingStep.finished);
      expect(reloaded.languageCode, 'en');
      expect(reloaded.agreementVersion, AppBranding.agreementVersion);
      expect(
        reloaded.agreementAcceptedAt?.toUtc(),
        DateTime.utc(2026, 11, 12, 9, 30),
      );
      expect(reloaded.needsOnboarding, isFalse);
    });

    test('reset clears the journey', () async {
      final store = OnboardingStore();
      await store.load();
      await store.acceptAgreement();
      await store.complete();

      await store.reset();
      expect(store.state.needsOnboarding, isTrue);
      expect(store.state.agreementAcceptedAt, isNull);
    });
  });
}
