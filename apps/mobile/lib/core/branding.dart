/// Official Sangguniang Bayan ng Mabini branding, in one place.
///
/// Every screen that shows the office identity reads from here so the mobile
/// and web builds cannot drift apart. [logoAsset] is the official Sangguniang
/// Bayan seal used *inside* the app and beside the app name; [iconAsset] is the
/// tricycle/document application icon used only for launcher/PWA/favicon.
abstract final class AppBranding {
  /// Short product name shown in app bars, the splash and the PWA manifest.
  static const String appName = 'SBTF System';

  /// The office that owns the system.
  static const String officeName = 'Sangguniang Bayan ng Mabini';

  /// Municipality and province, used as the second branding line.
  static const String location = 'Mabini, Batangas';

  /// Full official system name. Used where there is room for it (welcome,
  /// settings, agreement), never in a compact app bar.
  static const String longName =
      'Sangguniang Bayan ng Mabini Franchising and Tricycle Driver '
      'Registration System';

  /// One-sentence description of what the system does.
  static const String tagline =
      'Franchising and driver registration for the Municipality of Mabini, '
      'Batangas.';

  /// The official Sangguniang Bayan seal — the logo shown inside the app and
  /// beside the app name (splash, login, headers, settings).
  static const String logoAsset = 'assets/branding/sb_seal.png';

  /// The official Sangguniang Bayan seal, kept as an explicit alias for screens
  /// that refer to the seal by name.
  static const String sealAsset = 'assets/branding/sb_seal.png';

  /// The tricycle/document application icon. This is only the launcher/app
  /// icon on the homescreen and the PWA/favicon — never the in-app logo.
  static const String iconAsset = 'assets/branding/app_icon.png';

  /// Version shown in Settings. Mirrors `pubspec.yaml`.
  static const String version = '0.1.0';

  /// The current User Agreement revision. Bump this whenever the agreement
  /// text changes; anyone who accepted an older revision is asked to accept
  /// the new one before continuing.
  static const String agreementVersion = '1.0';

  /// Human-readable effective date for the current agreement revision.
  static const String agreementEffectiveDate = '12 November 2026';

  /// The law that governs personal data handling in this system.
  static const String privacyLaw =
      'Republic Act No. 10173 (Data Privacy Act of 2012)';

  /// Public address of the deployed driver web build. Used as readable text
  /// in the agreement; never used to make network calls.
  static const String publicUrl = 'https://sbtf-application.vercel.app';
}
