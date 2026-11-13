import 'package:shared_preferences/shared_preferences.dart';

import '../branding.dart';
import 'language.dart';
import 'onboarding_state.dart';

/// Reads and writes the first-run experience state.
///
/// The store is deliberately a plain class with an in-memory fallback: if the
/// platform store is unavailable (for example a widget test without a mock
/// plugin), onboarding still works for the session and never crashes the app.
class OnboardingStore {
  OnboardingStore({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;
  OnboardingState _state = OnboardingState.initial;

  OnboardingState get state => _state;

  bool get isPersistent => _preferences != null;

  /// Loads persisted values. A failure degrades to a fresh state rather than
  /// blocking launch — the driver can still complete onboarding, it just will
  /// not be remembered across restarts.
  Future<OnboardingState> load() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      _state = OnboardingState.fromPreferences(_preferences!);
    } catch (_) {
      _state = OnboardingState.initial;
    }
    return _state;
  }

  Future<void> saveStep(int step) async {
    if (step == _state.step) return;
    _state = _state.copyWith(step: step);
    await _persist();
  }

  Future<void> setLanguage(String code) async {
    final supported =
        AppLanguages.isSupported(code) ? code : AppLanguages.fallbackCode;
    if (supported == _state.languageCode) return;
    _state = _state.copyWith(languageCode: supported);
    await _persist();
  }

  /// Records acceptance of the current agreement revision. The timestamp is
  /// stored locally and, for signed-in drivers, synced to Supabase by
  /// `AgreementService`.
  Future<void> acceptAgreement({DateTime? acceptedAt}) async {
    _state = _state.copyWith(
      agreementVersion: AppBranding.agreementVersion,
      agreementAcceptedAt: (acceptedAt ?? DateTime.now()).toUtc(),
    );
    await _persist();
  }

  Future<void> complete() async {
    _state = _state.copyWith(
      completed: true,
      step: OnboardingStep.finished,
    );
    await _persist();
  }

  /// Clears the local journey so the introduction can be shown again. The
  /// agreement revision is cleared too, which means it must be accepted again
  /// the next time onboarding finishes.
  Future<void> reset() async {
    _state = OnboardingState.initial;
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.remove(OnboardingState.keyCompleted);
      await preferences.remove(OnboardingState.keyStep);
      await preferences.remove(OnboardingState.keyLanguage);
      await preferences.remove(OnboardingState.keyAgreementVersion);
      await preferences.remove(OnboardingState.keyAgreementAcceptedAt);
    } catch (_) {
      // Keep the in-memory reset even if storage is unavailable.
    }
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setBool(
        OnboardingState.keyCompleted,
        _state.completed,
      );
      await preferences.setInt(OnboardingState.keyStep, _state.step);
      await preferences.setString(
        OnboardingState.keyLanguage,
        _state.languageCode,
      );
      final version = _state.agreementVersion;
      if (version == null) {
        await preferences.remove(OnboardingState.keyAgreementVersion);
      } else {
        await preferences.setString(
          OnboardingState.keyAgreementVersion,
          version,
        );
      }
      final acceptedAt = _state.agreementAcceptedAt;
      if (acceptedAt == null) {
        await preferences.remove(OnboardingState.keyAgreementAcceptedAt);
      } else {
        await preferences.setString(
          OnboardingState.keyAgreementAcceptedAt,
          acceptedAt.toIso8601String(),
        );
      }
    } catch (_) {
      // Storage is a convenience here; the session still holds the state.
    }
  }
}
