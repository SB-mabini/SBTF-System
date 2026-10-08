import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/env.dart';

void main() {
  tearDown(() {
    currentEnv = Env.fromEnvironment;
  });

  group('Env.isConfigured', () {
    test('is false when no values are provided', () {
      const env = Env();
      expect(env.isConfigured, isFalse);
    });

    test('is true with a real https URL and a long key', () {
      const env = Env(
        supabaseUrl: 'https://abcdefghijklmnop.supabase.co',
        supabaseAnonKey: 'a-very-long-publishable-key-0123456789',
      );
      expect(env.isConfigured, isTrue);
    });

    test('is false for the placeholder project URL', () {
      const env = Env(
        supabaseUrl: 'https://your-project-ref.supabase.co',
        supabaseAnonKey: 'a-very-long-publishable-key-0123456789',
      );
      expect(env.isConfigured, isFalse);
    });

    test('is false when the key is too short', () {
      const env = Env(
        supabaseUrl: 'https://abcdefghijklmnop.supabase.co',
        supabaseAnonKey: 'short',
      );
      expect(env.isConfigured, isFalse);
    });
  });

  group('Env.isDemoMode', () {
    test('defaults to false', () {
      const env = Env();
      expect(env.isDemoMode, isFalse);
    });

    test('is true only when demoMode is set', () {
      const env = Env(demoMode: true);
      expect(env.isDemoMode, isTrue);
    });
  });

  group('runCommand', () {
    test('documents both required --dart-define flags', () {
      expect(runCommand, contains('--dart-define=SUPABASE_URL'));
      expect(runCommand, contains('--dart-define=SUPABASE_ANON_KEY'));
      expect(runCommand, startsWith('flutter run'));
    });
  });

  group('currentEnv override', () {
    test('top-level helpers follow the active configuration', () {
      currentEnv = const Env(
        supabaseUrl: 'https://abcdefghijklmnop.supabase.co',
        supabaseAnonKey: 'a-very-long-publishable-key-0123456789',
      );
      expect(isConfigured, isTrue);
      expect(isDemoMode, isFalse);
    });
  });
}
