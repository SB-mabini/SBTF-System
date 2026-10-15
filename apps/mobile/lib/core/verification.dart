/// Certificate verification helpers.
///
/// These mirror `apps/web/src/lib/verification.ts` so a code scanned in the
/// mobile app resolves to exactly the same value the web console builds into
/// the certificate QR code. The QR payload carries only the public verification
/// address and the opaque code — never a name, plate number or other personal
/// data.
library;

import 'constants.dart';

/// Keeps only characters that belong to the verification alphabet, after
/// upper-casing the input.
///
/// Spaces, dashes and the confusable I/O/0/1 are dropped, so a code read off a
/// printed certificate can be typed without worrying about separators.
String normaliseVerificationCode(String input) {
  final upper = input.trim().toUpperCase();
  final buffer = StringBuffer();
  for (final character in upper.split('')) {
    if (verificationCodeAlphabet.contains(character)) buffer.write(character);
  }
  return buffer.toString();
}

/// True when [code] is already a normalised, well-formed verification code.
bool isWellFormedVerificationCode(String code) {
  if (code.length != verificationCodeLength) return false;
  for (final character in code.split('')) {
    if (!verificationCodeAlphabet.contains(character)) return false;
  }
  return true;
}

/// The complete QR payload: the public verification base URL plus the
/// normalised code as a query parameter.
///
/// `baseUrl` is the `certificate_verification_base_url` system setting. Any
/// trailing slashes are removed so the result never contains a double slash.
String buildVerificationUrl(String baseUrl, String code) {
  final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  return '$base?code=${normaliseVerificationCode(code)}';
}

/// Reads a verification code out of a scanned QR payload.
///
/// A scanned value is normally the full verification URL, but it may also be a
/// bare code. The `code` query parameter wins when present; otherwise the whole
/// value is normalised (which strips any URL punctuation).
String extractVerificationCode(String scannedValue) {
  final uri = Uri.tryParse(scannedValue.trim());
  if (uri != null && uri.queryParameters['code'] != null) {
    return normaliseVerificationCode(uri.queryParameters['code']!);
  }
  return normaliseVerificationCode(scannedValue);
}

/// The value the app encodes into a certificate's QR code (slice 6).
///
/// Mirrors the web console: the payload is the public verification URL when
/// `certificate_verification_base_url` is configured. When it is not, the bare
/// verification code is encoded instead — [extractVerificationCode] resolves it
/// to the same value, so a scan still works.
String certificateQrPayload({
  required String? baseUrl,
  required String verificationCode,
}) {
  final base = (baseUrl ?? '').trim();
  if (base.isEmpty) return normaliseVerificationCode(verificationCode);
  return buildVerificationUrl(base, verificationCode);
}
