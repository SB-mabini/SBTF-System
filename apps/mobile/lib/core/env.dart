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

  /// The configuration compiled from `--dart-define` values. If not provided at
  /// build time, it defaults to the active project credentials.
  static const Env fromEnvironment = Env(
    supabaseUrl: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://qdtmzgaxktebyhsxrgvf.supabase.co',
    ),
    supabaseAnonKey: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkdG16Z2F4a3RlYnloc3hyZ3ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwNzEwNzYsImV4cCI6MjEwNjY0NzA3Nn0.J3ctXpR42Th75ZihOJ-3XPLHuOFPdxB8B5EWXIEwwTg',
    ),
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
