/// Classification of Supabase failures for the mobile data layer.
///
/// The web console classifies the same failures in
/// `apps/web/src/lib/supabase/errors.ts` and routes blocking ones to
/// `/setup-required`. The mobile app cannot show a setup page, but it still
/// needs the same taxonomy so a driver sees an honest, actionable message
/// instead of a raw PostgREST string. Each failure carries a one-sentence
/// [AppFailure.message] and, where there is something the driver can do, an
/// [AppFailure.hint] — the same reason/hint pair the web console shows.
///
///   * `schemaMissing`   → the project was never migrated (blocking)
///   * `unreachable`     → the project or the network is unavailable (blocking)
///   * `unauthorised`    → the session/key was refused; a session-level refusal
///                         is recoverable by signing in again (not blocking), a
///                         project-level refusal is blocking
///   * `businessRule`    → a validated RPC refused the request (P0001/P0002)
///   * `demoBlocked`     → preview mode; no database is connected
///   * `unknown`         → anything else; never treated as blocking
///
/// Blocking failures are the ones where no screen can render usefully and the
/// user must check configuration or connectivity rather than retry.
library;

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a database call failed, at the level the interface cares about.
enum AppFailureKind {
  schemaMissing,
  unreachable,
  unauthorised,
  businessRule,
  demoBlocked,
  unknown,
}

/// A single, user-presentable failure.
class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.hint,
    this.recoverable,
    this.code,
    this.detail,
  });

  final AppFailureKind kind;

  /// One sentence, safe to show to a driver or operator.
  final String message;

  /// What the user can do about it, shown under [message]. Null when there is
  /// nothing actionable — mirrors the web console's `hint`.
  final String? hint;

  /// For an [AppFailureKind.unauthorised] failure: true when signing in again
  /// fixes it (a session error), false when only the server can (a rotated key
  /// or missing row-level security). Null for every other kind.
  final bool? recoverable;

  /// The underlying PostgREST / PostgreSQL code, when the error carried one.
  final String? code;

  /// The raw server message, kept for logging only — not shown verbatim.
  final String? detail;

  /// True when nothing can render usefully until the environment is fixed.
  ///
  /// A session-level refusal is not blocking because signing in again recovers
  /// it; a project-level refusal (a rotated key, missing RLS) only clears
  /// server-side.
  bool get blocking {
    switch (kind) {
      case AppFailureKind.schemaMissing:
      case AppFailureKind.unreachable:
        return true;
      case AppFailureKind.unauthorised:
        return recoverable != true;
      case AppFailureKind.businessRule:
      case AppFailureKind.demoBlocked:
      case AppFailureKind.unknown:
        return false;
    }
  }

  /// The block produced by demo/preview mode, where no database is connected.
  static const AppFailure demoBlocked = AppFailure(
    kind: AppFailureKind.demoBlocked,
    message: 'Preview mode is on, so this action is disabled. '
        'Connect a Supabase project to use it.',
  );

  @override
  String toString() => detail == null ? message : '$message ($detail)';
}

/// PostgreSQL / PostgREST codes that mean "the schema is not what we expect".
const Set<String> _schemaMissingCodes = {
  'PGRST200', // relationship not found in the schema cache
  'PGRST201', // embedded resource not found
  'PGRST202', // function not found in the schema cache
  'PGRST203', // ambiguous function
  'PGRST204', // column not found in the schema cache
  'PGRST205', // table not found in the schema cache
  '42P01', // undefined_table
  '42703', // undefined_column
  '42704', // undefined_object
  '42883', // undefined_function
  '42P17', // infinite recursion in a policy
};

/// Codes that mean the session or key was refused.
const Set<String> _unauthorisedCodes = {
  'PGRST300', // JWT expired
  'PGRST301', // JWT invalid
  'PGRST302', // JWT not provided
  '42501', // insufficient_privilege
  '28000', // invalid_authorization_specification
  '28P01', // invalid_password
};

/// Transport-level codes Node/Dart raise when the host is unreachable.
const Set<String> _unreachableCodes = {
  'ETIMEDOUT',
  'ECONNREFUSED',
  'ECONNRESET',
  'ENOTFOUND',
  'EAI_AGAIN',
};

/// Codes the database raises after its own validation refuses a request.
const Set<String> _businessRuleCodes = {
  'P0001', // raise_exception from a validation branch
  'P0002', // no_data_found / record not found
  '23514', // check_violation
  '23503', // foreign_key_violation
  '23505', // unique_violation
};

final RegExp _schemaPattern = RegExp(
  r"schema cache|could not find the .* (table|column|function)|"
  r"relation .* does not exist|column .* (does not exist|of relation)|"
  r"function .*\(.*\) does not exist|undefined_table|undefined_column|"
  r"undefined_function|undefined_object",
  caseSensitive: false,
);
final RegExp _unauthorisedPattern = RegExp(
  r'permission denied|row[- ]level security|invalid api key|invalid jwt|'
  r'jwt (expired|is invalid|malformed|not valid)|no api key found|'
  r'invalid_authorization_specification|invalid_password|\bunauthorized\b|'
  r'\bforbidden\b',
  caseSensitive: false,
);
final RegExp _unreachablePattern = RegExp(
  r'failed host lookup|connection refused|connection closed|network is unreachable|'
  r'socketexception|socket hang up|failed to fetch|xmlhttprequest|'
  r'networkerror|network request failed|load failed|clientexception|'
  r'handshakeexception|http exception|connection tim(ed out|eout)|'
  r'timeout|timed out|terminated|abort',
  caseSensitive: false,
);
final RegExp _sessionPattern = RegExp(
  r'auth session|session (missing|expired|not found)|invalid refresh token|'
  r'refresh token.*(invalid|expired|not found)|sign in again|email not confirmed',
  caseSensitive: false,
);
final RegExp _parenthesisedCode =
    RegExp(r'\(([0-9a-z]{5})\)', caseSensitive: false);

String? _codeOf(Object error) {
  if (error is PostgrestException &&
      error.code != null &&
      error.code!.isNotEmpty) {
    return error.code;
  }
  if (error is AuthException &&
      error.statusCode != null &&
      error.statusCode!.isNotEmpty) {
    return error.statusCode;
  }
  // PostgreSQL and PostgREST both put the code in parentheses inside the
  // message, mirroring the web console's `codeOf`.
  return _parenthesisedCode
      .firstMatch(_messageOf(error))
      ?.group(1)
      ?.toUpperCase();
}

String _messageOf(Object error) {
  if (error is PostgrestException) {
    // PostgREST splits the human detail from the raw message: a generic
    // `message` often carries the real cause in `details` or `hint`.
    return [error.message, error.details, error.hint]
        .whereType<String>()
        .join(' ');
  }
  if (error is AuthException) return error.message;
  if (error is StorageException) return error.message;
  if (error is Error) return error.toString();
  return error.toString();
}

/// The HTTP status, when the error carried one as a number or a numeric string.
int? _statusOf(Object error) {
  if (error is AuthException) return int.tryParse(error.statusCode ?? '');
  return null;
}

/// True for a Dart transport exception, whatever its message says.
bool _isTransportType(Object error) =>
    error is SocketException ||
    error is HttpException ||
    error is HandshakeException ||
    error is TimeoutException;

/// True when the error is a GoTrue *session* error — an expired cookie or a
/// stale refresh token. These are a normal part of authentication (the visitor
/// signs in again), not a broken environment, so they must not be blocking.
///
/// Like the web console, the distinction is made on the error's *identity*: a
/// Dart [AuthException] is GoTrue's `Auth*Error`. PostgREST refusals (a rotated
/// key, missing RLS) are `PostgrestException`s and stay project-level.
bool _isSessionError(Object error) {
  if (error is AuthException) return true;
  return _sessionPattern.hasMatch(_messageOf(error));
}

/// Maps any thrown object onto an [AppFailure].
///
/// Order matters: a schema or transport problem can surface with an HTTP 400
/// and a five-character code, so those are recognised before the generic
/// authorisation branch. A validated `raise exception` from one of the driver
/// RPCs carries a friendly message already ("You already have a pending new
/// franchise application", "Each document must not exceed 10 MB"), so its
/// message is shown as-is. This mirrors the web console's
/// `classifyDatabaseError`.
AppFailure classifyAppError(Object error) {
  if (error is AppFailure) return error;

  final code = _codeOf(error);
  final status = _statusOf(error);
  final raw = _messageOf(error);
  final haystack = '${code ?? ''} $raw';

  // 1. The database does not match the schema this app expects.
  if ((code != null && _schemaMissingCodes.contains(code)) ||
      _schemaPattern.hasMatch(haystack)) {
    return AppFailure(
      kind: AppFailureKind.schemaMissing,
      message: 'The database is not ready. It does not match the schema this '
          'app expects.',
      hint: 'The municipal office must apply the database migrations.',
      code: code,
      detail: raw,
    );
  }

  // 2. The project or the network could not be reached.
  if (_isTransportType(error) ||
      (code != null && _unreachableCodes.contains(code)) ||
      status == 0 ||
      status == 502 ||
      status == 503 ||
      status == 504 ||
      _unreachablePattern.hasMatch(haystack)) {
    return AppFailure(
      kind: AppFailureKind.unreachable,
      message: 'Could not reach the municipal service. '
          'Check your connection and try again.',
      hint: 'Turn on Wi-Fi or mobile data, then try again.',
      code: code,
      detail: raw,
    );
  }

  // 3. A validated RPC refused the request with a business-rule message.
  if (code != null && _businessRuleCodes.contains(code)) {
    return AppFailure(
      kind: AppFailureKind.businessRule,
      message: raw.trim(),
      code: code,
      detail: raw,
    );
  }

  // 4. The session or the key was refused. A GoTrue `AuthException` is always
  //    an authorisation problem, even when its message (e.g. "Invalid login
  //    credentials") matches none of the patterns below.
  if (error is AuthException ||
      (code != null && _unauthorisedCodes.contains(code)) ||
      status == 401 ||
      status == 403 ||
      _unauthorisedPattern.hasMatch(haystack)) {
    final sessionLevel = _isSessionError(error);
    return AppFailure(
      kind: AppFailureKind.unauthorised,
      message: sessionLevel
          ? 'Your session is no longer valid. Please sign in again.'
          : 'The municipal service refused this request from your session.',
      hint: sessionLevel
          ? 'Sign in again to continue.'
          : 'Sign in again. If this keeps happening, contact the municipal '
              'office.',
      recoverable: sessionLevel,
      code: code,
      detail: raw,
    );
  }

  // 5. Anything else — show the server message when it looks presentable,
  //    otherwise a neutral fallback.
  final trimmed = raw.trim();
  return AppFailure(
    kind: AppFailureKind.unknown,
    message: trimmed.isEmpty || trimmed.startsWith('PostgrestException')
        ? 'The request could not be completed. Please try again.'
        : trimmed,
    hint: 'Try again. If it keeps happening, contact the municipal office.',
    code: code,
    detail: raw,
  );
}

/// True when [error] classifies as a blocking environment failure.
bool isBlockingFailure(Object error) => classifyAppError(error).blocking;
