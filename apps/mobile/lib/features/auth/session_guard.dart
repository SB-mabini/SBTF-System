import '../../core/models/profile.dart';

/// The possible outcomes of evaluating a session, in the precedence order the
/// guard applies them. Keeping the decision as a pure enum (rather than inline
/// widget logic) makes the whole session policy unit-testable.
enum SessionDecision {
  /// No authenticated session at all → show the sign-in screen.
  requireLogin,

  /// Signed in, but the e-mail address has not been confirmed yet.
  requireEmailVerification,

  /// Signed in and confirmed, but no profile row exists for this account.
  profileMissing,

  /// The profile exists but is not a driver/operator (web roles belong on the
  /// web console, not in this app).
  refuseNonDriver,

  /// The account is suspended (disciplinary lock).
  refuseSuspended,

  /// The account is otherwise inactive.
  refuseInactive,

  /// Everything checks out → show the home screen.
  allow,
}

/// Pure evaluation of the session policy. No I/O, so it is fully testable.
///
/// Precedence (first match wins), matching the enum order:
/// 1. no session            → requireLogin
/// 2. e-mail not confirmed  → requireEmailVerification
/// 3. no profile            → profileMissing
/// 4. role is not driver    → refuseNonDriver
/// 5. suspended             → refuseSuspended
/// 6. not active            → refuseInactive
/// 7. otherwise             → allow
SessionDecision evaluateSession({
  required bool hasSession,
  required bool emailConfirmed,
  required Profile? profile,
}) {
  if (!hasSession) return SessionDecision.requireLogin;
  if (!emailConfirmed) return SessionDecision.requireEmailVerification;
  if (profile == null) return SessionDecision.profileMissing;
  if (!profile.isDriver) return SessionDecision.refuseNonDriver;
  if (profile.isSuspended) return SessionDecision.refuseSuspended;
  if (!profile.isActive) return SessionDecision.refuseInactive;
  return SessionDecision.allow;
}

/// Short, human-readable reason for each refusal, shown on the refusal cards.
String decisionReason(SessionDecision decision) {
  switch (decision) {
    case SessionDecision.requireLogin:
      return 'Sign in with your driver or operator account to continue.';
    case SessionDecision.requireEmailVerification:
      return 'Please confirm your e-mail address before signing in. '
          'Check your inbox for the verification link.';
    case SessionDecision.profileMissing:
      return 'No profile is linked to this account yet. '
          'Contact the municipal office to complete your registration.';
    case SessionDecision.refuseNonDriver:
      return 'Municipal staff and administrators use the web console. '
          'This app is for drivers and operators only.';
    case SessionDecision.refuseSuspended:
      return 'This account has been suspended. '
          'Contact the municipal office for details.';
    case SessionDecision.refuseInactive:
      return 'This account is not active. '
          'Contact the municipal office to restore access.';
    case SessionDecision.allow:
      return '';
  }
}
