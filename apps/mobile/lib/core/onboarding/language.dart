/// Languages the application can actually render today.
///
/// The requirement is explicit: do not offer a language that is not
/// implemented. Every string in this build is English, so English is the only
/// option the selector exposes. Adding a language later means adding it here,
/// translating the strings, and persisting its [AppLanguage.code] — the
/// onboarding flow and Settings already handle an arbitrary supported list.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
  });

  /// BCP-47 language tag stored in preferences.
  final String code;

  /// Name as written in English, for the selector.
  final String englishName;

  /// Name as written in the language itself.
  final String nativeName;

  String get displayName =>
      nativeName == englishName ? englishName : '$nativeName ($englishName)';
}

abstract final class AppLanguages {
  static const AppLanguage english = AppLanguage(
    code: 'en',
    englishName: 'English',
    nativeName: 'English',
  );

  /// Every language this build fully supports.
  static const List<AppLanguage> supported = <AppLanguage>[english];

  static const String fallbackCode = 'en';

  static AppLanguage byCode(String? code) {
    for (final language in supported) {
      if (language.code == code) return language;
    }
    return english;
  }

  static bool isSupported(String code) =>
      supported.any((language) => language.code == code);
}
