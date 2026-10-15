import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('classifyAppError — schema missing', () {
    test('recognises a missing function from the PostgREST code', () {
      final failure = classifyAppError(
        PostgrestException(
          message:
              'Could not find the function public.rpc_driver_submit_application',
          code: 'PGRST202',
        ),
      );

      expect(failure.kind, AppFailureKind.schemaMissing);
      expect(failure.blocking, isTrue);
      expect(failure.code, 'PGRST202');
    });

    test('recognises a missing table from the server message', () {
      final failure = classifyAppError(
        PostgrestException(
          message: 'relation "public.franchise_records" does not exist',
        ),
      );

      expect(failure.kind, AppFailureKind.schemaMissing);
    });

    test('recognises an undefined column code', () {
      final failure = classifyAppError(
        PostgrestException(message: 'column does not exist', code: '42703'),
      );

      expect(failure.kind, AppFailureKind.schemaMissing);
    });
  });

  group('classifyAppError — unreachable', () {
    test('recognises a DNS / connection failure', () {
      final failure = classifyAppError(
        Exception(
            'SocketException: Failed host lookup: qdtmzgaxktebyhsxrgvf.supabase.co'),
      );

      expect(failure.kind, AppFailureKind.unreachable);
      expect(failure.blocking, isTrue);
    });

    test('recognises a timeout', () {
      final failure = classifyAppError(Exception('Connection timed out'));

      expect(failure.kind, AppFailureKind.unreachable);
    });
  });

  group('classifyAppError — business rule', () {
    test('shows the server message for a raised exception', () {
      final failure = classifyAppError(
        PostgrestException(
          message: 'You already have a pending new franchise application.',
          code: 'P0001',
        ),
      );

      expect(failure.kind, AppFailureKind.businessRule);
      expect(failure.blocking, isFalse);
      expect(failure.message,
          'You already have a pending new franchise application.');
    });

    test('recognises a unique violation', () {
      final failure = classifyAppError(
        PostgrestException(message: 'duplicate key value', code: '23505'),
      );

      expect(failure.kind, AppFailureKind.businessRule);
    });
  });

  group('classifyAppError — unauthorised', () {
    test('recognises an AuthException', () {
      final failure = classifyAppError(
        const AuthException('Invalid login credentials', statusCode: '400'),
      );

      expect(failure.kind, AppFailureKind.unauthorised);
      expect(failure.blocking, isFalse);
    });

    test('recognises an insufficient-privilege code', () {
      final failure = classifyAppError(
        PostgrestException(
            message: 'permission denied for table documents', code: '42501'),
      );

      expect(failure.kind, AppFailureKind.unauthorised);
    });
  });

  group('classifyAppError — fallbacks', () {
    test('passes an existing AppFailure through unchanged', () {
      const original = AppFailure(
        kind: AppFailureKind.businessRule,
        message: 'No file was selected.',
      );

      expect(identical(classifyAppError(original), original), isTrue);
    });

    test('keeps a presentable server message for an unknown failure', () {
      final failure = classifyAppError(Exception('Something unexpected'));

      expect(failure.kind, AppFailureKind.unknown);
      expect(failure.message, contains('Something unexpected'));
    });

    test('uses a neutral fallback when the message is not presentable', () {
      final failure = classifyAppError('PostgrestException(message: oops)');

      expect(failure.kind, AppFailureKind.unknown);
      expect(failure.message,
          'The request could not be completed. Please try again.');
    });
  });

  group('blocking helpers', () {
    test('demoBlocked is not a blocking failure', () {
      expect(AppFailure.demoBlocked.kind, AppFailureKind.demoBlocked);
      expect(AppFailure.demoBlocked.blocking, isFalse);
    });

    test('isBlockingFailure mirrors AppFailure.blocking', () {
      expect(
        isBlockingFailure(PostgrestException(message: 'x', code: '42P01')),
        isTrue,
      );
      expect(
        isBlockingFailure(PostgrestException(message: 'x', code: 'P0001')),
        isFalse,
      );
    });
  });

  group('classifyAppError — transport detection (slice 8)', () {
    test('recognises a SocketException by type, not just its message', () {
      final failure = classifyAppError(
        const SocketException('Failed host lookup: example.supabase.co'),
      );

      expect(failure.kind, AppFailureKind.unreachable);
      expect(failure.blocking, isTrue);
    });

    test('recognises a TimeoutException by type', () {
      final failure = classifyAppError(TimeoutException('request timed out'));

      expect(failure.kind, AppFailureKind.unreachable);
    });

    test('treats a 503 from the auth endpoint as unreachable', () {
      final failure = classifyAppError(
        const AuthException('Service unavailable', statusCode: '503'),
      );

      expect(failure.kind, AppFailureKind.unreachable);
      expect(failure.blocking, isTrue);
    });
  });

  group('classifyAppError — hints (slice 8)', () {
    test('a schema failure carries an actionable hint', () {
      final failure = classifyAppError(
        PostgrestException(message: 'x', code: 'PGRST205'),
      );

      expect(failure.hint, isNotNull);
      expect(failure.hint, isNotEmpty);
    });

    test('an unreachable failure carries a connection hint', () {
      final failure = classifyAppError(Exception('Connection refused'));

      expect(failure.kind, AppFailureKind.unreachable);
      expect(failure.hint, contains('Wi-Fi'));
    });

    test('a business-rule failure needs no hint — its message is specific', () {
      final failure = classifyAppError(
        PostgrestException(message: 'No file was selected.', code: 'P0001'),
      );

      expect(failure.hint, isNull);
    });
  });

  group('classifyAppError — authorisation depth (slice 8)', () {
    test('a project-level refusal (42501) is blocking and not recoverable', () {
      final failure = classifyAppError(
        PostgrestException(
            message: 'permission denied for table documents', code: '42501'),
      );

      expect(failure.kind, AppFailureKind.unauthorised);
      expect(failure.recoverable, isFalse);
      expect(failure.blocking, isTrue);
    });

    test('a PostgREST JWT refusal (PGRST301) is project-level and blocking',
        () {
      final failure = classifyAppError(
        PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      );

      expect(failure.kind, AppFailureKind.unauthorised);
      expect(failure.blocking, isTrue);
    });

    test('a GoTrue session refusal is recoverable and not blocking', () {
      final failure = classifyAppError(
        const AuthException('JWT expired', statusCode: '401'),
      );

      expect(failure.kind, AppFailureKind.unauthorised);
      expect(failure.recoverable, isTrue);
      expect(failure.blocking, isFalse);
    });
  });

  group('classifyAppError — PostgREST details (slice 8)', () {
    test('classifies on the details field when the message is generic', () {
      final failure = classifyAppError(
        PostgrestException(
          message: 'Database error',
          details: 'relation "public.franchise_records" does not exist',
        ),
      );

      expect(failure.kind, AppFailureKind.schemaMissing);
    });
  });
}
