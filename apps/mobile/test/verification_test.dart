import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/constants.dart';
import 'package:sbtf_mobile/core/verification.dart';

void main() {
  group('normaliseVerificationCode', () {
    test('upper-cases and drops separators', () {
      expect(normaliseVerificationCode('abcd efgh jklm'), 'ABCDEFGHJKLM');
      expect(normaliseVerificationCode('  AB-CD.EF_GH  '), 'ABCDEFGH');
    });

    test('drops the confusable I, O, 0 and 1', () {
      expect(normaliseVerificationCode('O0I1'), '');
      expect(normaliseVerificationCode('A0B1CIOD'), 'ABCD');
    });

    test('keeps only characters from the verification alphabet', () {
      for (final character
          in normaliseVerificationCode('abc!@#def').split('')) {
        expect(verificationCodeAlphabet.contains(character), isTrue);
      }
    });
  });

  group('isWellFormedVerificationCode', () {
    test('accepts a normalised code of the exact length', () {
      expect(isWellFormedVerificationCode('ABCDEFGHJKLM'), isTrue);
    });

    test('rejects the wrong length', () {
      expect(isWellFormedVerificationCode('ABCDEFGHJKL'), isFalse);
      expect(isWellFormedVerificationCode('ABCDEFGHJKLMN'), isFalse);
    });

    test('rejects characters outside the alphabet', () {
      expect(isWellFormedVerificationCode('ABCDEFGHJKL0'), isFalse);
      expect(isWellFormedVerificationCode('abcdefghjklm'), isFalse);
    });
  });

  group('buildVerificationUrl', () {
    test('appends the normalised code as a query parameter', () {
      expect(
        buildVerificationUrl('https://mabini.gov.ph/verify', 'ABCD-EFGH-JKLM'),
        'https://mabini.gov.ph/verify?code=ABCDEFGHJKLM',
      );
    });

    test('removes any trailing slashes from the base URL', () {
      expect(
        buildVerificationUrl('https://mabini.gov.ph/verify///', 'abcdefghjklm'),
        'https://mabini.gov.ph/verify?code=ABCDEFGHJKLM',
      );
    });
  });

  group('extractVerificationCode', () {
    test('reads the code query parameter from a scanned URL', () {
      expect(
        extractVerificationCode(
            'https://mabini.gov.ph/verify?code=ab-cd-ef-gh'),
        'ABCDEFGH',
      );
    });

    test('normalises a bare code', () {
      expect(extractVerificationCode('  abcd efgh  '), 'ABCDEFGH');
    });

    test('prefers the query parameter over the rest of the URL', () {
      expect(
        extractVerificationCode('https://mabini.gov.ph/verify?code=JKLM'),
        'JKLM',
      );
    });
  });

  group('certificateQrPayload', () {
    test('builds the verification URL when a base URL is configured', () {
      expect(
        certificateQrPayload(
          baseUrl: 'https://mabini.gov.ph/verify',
          verificationCode: 'ABCD EFGH JKLM',
        ),
        'https://mabini.gov.ph/verify?code=ABCDEFGHJKLM',
      );
    });

    test('falls back to the bare normalised code without a base URL', () {
      // The scanner resolves both shapes to the same code, so a missing
      // setting still yields a scannable QR.
      expect(
        certificateQrPayload(baseUrl: null, verificationCode: 'abcd-efgh-jklm'),
        'ABCDEFGHJKLM',
      );
      expect(
        certificateQrPayload(baseUrl: '   ', verificationCode: 'ABCDEFGHJKLM'),
        'ABCDEFGHJKLM',
      );
    });

    test('round-trips through extractVerificationCode', () {
      final payload = certificateQrPayload(
        baseUrl: 'https://mabini.gov.ph/verify',
        verificationCode: 'ABCDEFGHJKLM',
      );
      expect(extractVerificationCode(payload), 'ABCDEFGHJKLM');
    });
  });
}
