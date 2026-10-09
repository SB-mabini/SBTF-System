/// Build-time configuration for the SBTF mobile application.
///
/// Values arrive through `--dart-define` at build time and are compiled into the
/// binary. Nothing in this file is a secret: the URL is public and the anon /
/// publishable key is intentionally shipped inside the app because Row Level
/// Security in PostgreSQL is the actual authorisation boundary.
///
/// Run with:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<publishable key>
/// ```
library;

/// Immutable snapshot of the configuration. A plain class (rather than bare
/// top-level constants) so that tests can construct deterministic instances and
/// `main.dart` can fall back safely when a define is missing.
class Env {
  const Env({
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.demoMode = false,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool demoMode;

  /// Preview mode, mirroring the web console: the interface runs without a
  /// database and every write is blocked. Enabled only by the exact string
  /// `true` passed as `SBTF_DEMO_MODE`.
  bool get isDemoMode => demoMode;

  /// True when both a reachable project URL and a key that looks like a real
  /// publishable key are present. Empty or placeholder defines leave this false,
  /// which routes the app to [ConfigMissingScreen] instead of crashing on
  /// `Supabase.initialize`.
  bool get isConfigured {
    final hasUrl = supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('your-project-ref');
    final hasKey = supabaseAnonKey.length > 20;
    return hasUrl && hasKey;
  }

  /// The configuration compiled from `--dart-define` values. This is the one the
  /// app boots with; tests override it by assigning [current].
  static const Env fromEnvironment = Env(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    demoMode: String.fromEnvironment('SBTF_DEMO_MODE') == 'true',
  );
}

/// The active configuration. Defaults to the compiled-in values; tests replace
/// it to exercise specific states.
Env currentEnv = Env.fromEnvironment;

/// Convenience accessors used across the app.
bool get isDemoMode => currentEnv.isDemoMode;
bool get isConfigured => currentEnv.isConfigured;

/// The exact command needed to run the app against a real project. Shown
/// verbatim on the config-missing screen so there is no guesswork.
String get runCommand =>
    'flutter run --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co '
    '--dart-define=SUPABASE_ANON_KEY=your-publishable-key';
