import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/profile.dart';
import 'package:sbtf_mobile/features/auth/session_guard.dart';

Profile _profile({String role = 'driver', String status = 'active'}) {
  return Profile(
    id: 'profile-1',
    role: role,
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    email: 'juan@example.com',
    accountStatus: status,
  );
}

void main() {
  group('evaluateSession precedence', () {
    test('no session requires login', () {
      expect(
        evaluateSession(
          hasSession: false,
          emailConfirmed: true,
          profile: _profile(),
        ),
        SessionDecision.requireLogin,
      );
    });

    test('unconfirmed e-mail requires verification', () {
      expect(
        evaluateSession(
          hasSession: true,
          emailConfirmed: false,
          profile: _profile(),
        ),
        SessionDecision.requireEmailVerification,
      );
    });

    test('confirmed but missing profile is reported', () {
      expect(
        evaluateSession(
          hasSession: true,
          emailConfirmed: true,
          profile: null,
        ),
        SessionDecision.profileMissing,
      );
    });

    test('a non-driver profile is refused', () {
      expect(
        evaluateSession(
          hasSession: true,
          emailConfirmed: true,
          profile: _profile(role: 'staff'),
        ),
        SessionDecision.refuseNonDriver,
      );
    });

    test('a suspended driver is refused', () {
      expect(
        evaluateSession(
          hasSession: true,
          emailConfirmed: true,
          profile: _profile(status: 'suspended'),
        ),
        SessionDecision.refuseSuspended,
      );
    });

    test('an inactive driver is refused', () {
      expect(
        evaluateSession(
          hasSession: true,
          emailConfirmed: true,
          profile: _profile(status: 'inactive'),
        ),
        SessionDecision.refuseInactive,
      );
    });

    test('an active driver is allowed', () {
      expect(
        evaluateSession(
          hasSession: true,
          emailConfirmed: true,
          profile: _profile(),
        ),
        SessionDecision.allow,
      );
    });

    test('requireLogin wins over unconfirmed e-mail and missing profile', () {
      expect(
        evaluateSession(
          hasSession: false,
          emailConfirmed: false,
          profile: null,
        ),
        SessionDecision.requireLogin,
      );
    });

    test('non-driver refusal wins over a suspended status', () {
      expect(
        evaluateSession(
          hasSession: true,
          emailConfirmed: true,
          profile: _profile(role: 'administrator', status: 'suspended'),
        ),
        SessionDecision.refuseNonDriver,
      );
    });
  });
}
