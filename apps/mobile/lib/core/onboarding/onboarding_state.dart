import 'package:shared_preferences/shared_preferences.dart';

import '../branding.dart';
import 'language.dart';

/// Named positions in the onboarding journey.
///
/// The flow is a single [PageView]; these constants are both the page index and
/// the value persisted as "how far the driver got", so an interrupted
/// onboarding can resume at the same place.
abstract final class OnboardingStep {
  static const int welcome = 0;
  static const int language = 1;
  static const int introFirst = 2;
  static const int introLast = 5;
  static const int agreement = 6;
  static const int finished = 7;
  static const int count = 8;
}

/// Persisted onboarding + agreement state.
///
/// Onboarding completion and language are user preferences and live on the
/// device. Agreement acceptance is additionally synced to Supabase for signed-in
/// drivers (see `AgreementService`), because a merely local record is not an
/// adequate audit trail.
class OnboardingState {
  const OnboardingState({
    this.completed = false,
    this.step = OnboardingStep.welcome,
    this.languageCode = AppLanguages.fallbackCode,
    this.agreementVersion,
    this.agreementAcceptedAt,
  });

  static const OnboardingState initial = OnboardingState();

  final bool completed;

  /// Last page the driver reached. [OnboardingStep.finished] once complete.
  final int step;

  final String languageCode;

  /// Agreement revision the driver accepted, if any.
  final String? agreementVersion;

  final DateTime? agreementAcceptedAt;

  String get language => AppLanguages.byCode(languageCode).code;

  bool get hasAcceptedAgreement => agreementVersion != null;

  bool get agreementIsCurrent =>
      agreementVersion == AppBranding.agreementVersion;

  /// True when the first-run experience (or a required re-acceptance) must be
  /// shown before the driver reaches sign-in.
  bool get needsOnboarding => !completed || !agreementIsCurrent;

  /// The page to resume from. Returning users whose agreement is still current
  /// never enter the flow; returning users with an outdated agreement resume
  /// directly at the agreement, skipping the welcome and introduction.
  int get resumeStep {
    // A completed user with an outdated revision only needs the agreement.
    if (completed && !agreementIsCurrent) return OnboardingStep.agreement;

    if (!completed) {
      // First run (or an interrupted first run): resume where the driver left
      // off, never beyond the agreement.
      if (step >= OnboardingStep.finished) return OnboardingStep.welcome;
      if (step < OnboardingStep.welcome) return OnboardingStep.welcome;
      if (step > OnboardingStep.agreement) return OnboardingStep.agreement;
      return step;
    }

    return OnboardingStep.finished;
  }

  OnboardingState copyWith({
    bool? completed,
    int? step,
    String? languageCode,
    String? agreementVersion,
    DateTime? agreementAcceptedAt,
    bool clearAgreement = false,
  }) {
    return OnboardingState(
      completed: completed ?? this.completed,
      step: step ?? this.step,
      languageCode: languageCode ?? this.languageCode,
      agreementVersion:
          clearAgreement ? null : agreementVersion ?? this.agreementVersion,
      agreementAcceptedAt: clearAgreement
          ? null
          : agreementAcceptedAt ?? this.agreementAcceptedAt,
    );
  }

  static const String keyCompleted = 'sbtf.onboarding.completed';
  static const String keyStep = 'sbtf.onboarding.step';
  static const String keyLanguage = 'sbtf.onboarding.language';
  static const String keyAgreementVersion = 'sbtf.agreement.version';
  static const String keyAgreementAcceptedAt = 'sbtf.agreement.accepted_at';

  factory OnboardingState.fromPreferences(SharedPreferences preferences) {
    final languageCode = preferences.getString(keyLanguage);
    final acceptedAt = preferences.getString(keyAgreementAcceptedAt);
    return OnboardingState(
      completed: preferences.getBool(keyCompleted) ?? false,
      step: preferences.getInt(keyStep) ?? OnboardingStep.welcome,
      languageCode: AppLanguages.isSupported(languageCode ?? '')
          ? languageCode!
          : AppLanguages.fallbackCode,
      agreementVersion: preferences.getString(keyAgreementVersion),
      agreementAcceptedAt:
          acceptedAt == null ? null : DateTime.tryParse(acceptedAt)?.toLocal(),
    );
  }
}
