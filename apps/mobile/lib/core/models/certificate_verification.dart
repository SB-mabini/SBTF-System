/// The result of resolving a certificate verification code through
/// `public.rpc_verify_certificate`.
///
/// The operator name arrives already masked by the database — the function
/// returns only non-sensitive fields, so no further masking is required here.
class CertificateVerification {
  const CertificateVerification({
    required this.verificationStatus,
    this.franchiseNumber,
    this.operatorDisplayName,
    this.todaName,
    this.issuedAt,
    this.expiresAt,
    this.verifiedAt,
  });

  /// `valid` | `expired` | `archived` | `not_found`.
  final String verificationStatus;

  final String? franchiseNumber;
  final String? operatorDisplayName;
  final String? todaName;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? verifiedAt;

  bool get isValid => verificationStatus == 'valid';

  /// Outcome label for the scanner result card (slice 6).
  String get statusLabel {
    switch (verificationStatus) {
      case 'valid':
        return 'Valid franchise';
      case 'expired':
        return 'Expired franchise';
      case 'archived':
        return 'Archived franchise';
      default:
        return 'Certificate not found';
    }
  }

  factory CertificateVerification.fromMap(Map<String, dynamic> map) {
    return CertificateVerification(
      verificationStatus:
          (map['verification_status'] ?? 'not_found').toString(),
      franchiseNumber: map['franchise_number']?.toString(),
      operatorDisplayName: map['operator_display_name']?.toString(),
      todaName: map['toda_name']?.toString(),
      issuedAt: _asDate(map['issued_at']),
      expiresAt: _asDate(map['expires_at']),
      verifiedAt: _asDate(map['verified_at']),
    );
  }

  /// The value used when a scan resolves to nothing, or when the verification
  /// call itself fails — so a scan result is never ambiguous.
  static CertificateVerification notFound() => CertificateVerification(
      verificationStatus: 'not_found', verifiedAt: DateTime.now());
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
