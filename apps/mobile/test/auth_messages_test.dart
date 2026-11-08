import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/features/auth/auth_messages.dart';

void main() {
  group('friendlyAuthMessage', () {
    test('maps bad credentials without leaking the server wording', () {
      expect(
        friendlyAuthMessage('Invalid login credentials'),
        'The e-mail address or password is incorrect.',
      );
    });

    test('sends an unconfirmed account to the code screen', () {
      expect(
        friendlyAuthMessage('Email not confirmed'),
        contains('6-digit code'),
      );
    });

    test('explains an expired or wrong OTP', () {
      expect(
        friendlyAuthMessage('Token has expired or is invalid'),
        contains('incorrect or has expired'),
      );
      expect(
        friendlyAuthMessage('Invalid OTP'),
        contains('incorrect or has expired'),
      );
    });

    test('explains rate limiting', () {
      expect(
        friendlyAuthMessage('Email rate limit exceeded'),
        contains('Wait a minute'),
      );
    });

    test('turns Android socket failures into a connection message', () {
      expect(
        friendlyAuthMessage('SocketException: Failed host lookup'),
        contains('No internet connection'),
      );
    });

    test('keeps an unknown message intact', () {
      expect(
        friendlyAuthMessage('Something new from GoTrue'),
        'Something new from GoTrue',
      );
    });
  });
}
