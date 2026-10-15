import '../models/certificate_verification.dart';
import '../models/franchise_record.dart';
import '../verification.dart';
import 'service_base.dart';

/// Certificate and QR handling — slice 6.
///
/// Drivers read their own `franchise_records` rows; the certificate file is
/// downloaded through a short-lived signed URL from the private `certificates`
/// bucket. Verification of a scanned code stays server-side and public:
/// `rpc_verify_certificate` returns only a masked name and the record's dates.
class CertificateService extends SupabaseService {
  CertificateService(super.client);

  static const String _recordSelect = '*, toda:todas(id, name, code), '
      'application:franchise_applications(plate_number, vehicle_make, vehicle_model, vehicle_year)';

  /// The caller's own franchise records, newest first.
  Future<List<FranchiseRecord>> listMine() {
    return guard(() async {
      final rows = await client
          .from('franchise_records')
          .select(_recordSelect)
          .order('issued_at', ascending: false);
      return rows
          .map((row) =>
              FranchiseRecord.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// One record by id, or null when it is not the caller's.
  Future<FranchiseRecord?> getById(String id) {
    return guard(() async {
      final row = await client
          .from('franchise_records')
          .select(_recordSelect)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return FranchiseRecord.fromMap(Map<String, dynamic>.from(row));
    });
  }

  /// The record a driver most likely wants on the home screen: the newest
  /// active (not archived, not expired) franchise, else the newest overall.
  Future<FranchiseRecord?> activeRecord() {
    return guard(() async {
      final records = await listMine();
      for (final record in records) {
        if (!record.archived && !record.isExpired) return record;
      }
      return records.isEmpty ? null : records.first;
    });
  }

  /// A short-lived signed URL for the certificate PDF, or null when the record
  /// has no certificate yet or the session may not read it.
  Future<String?> certificateSignedUrl(FranchiseRecord record,
      {int expiresIn = 300}) {
    return certificateSignedUrlForPath(record.certificateStoragePath,
        expiresIn: expiresIn);
  }

  /// Variant that takes the storage path directly.
  Future<String?> certificateSignedUrlForPath(String? storagePath,
      {int expiresIn = 300}) {
    return guard(() async {
      if (storagePath == null || storagePath.isEmpty) return null;
      try {
        return await client.storage
            .from('certificates')
            .createSignedUrl(storagePath, expiresIn);
      } catch (_) {
        return null;
      }
    });
  }

  /// Resolves a scanned or typed verification code through the public RPC.
  ///
  /// The input may be a full verification URL (as produced by
  /// [buildVerificationUrl]) or a bare code; both are normalised. A failed call
  /// resolves to [CertificateVerification.notFound] so the scanner result is
  /// never ambiguous.
  Future<CertificateVerification> verify(String scannedValue) {
    return guard(() async {
      final code = extractVerificationCode(scannedValue);
      if (!isWellFormedVerificationCode(code)) {
        return CertificateVerification.notFound();
      }

      try {
        final data = await client.rpc(
          'rpc_verify_certificate',
          params: {'p_code': code},
        );
        final row = _firstRow(data);
        if (row == null) return CertificateVerification.notFound();
        return CertificateVerification.fromMap(row);
      } catch (_) {
        return CertificateVerification.notFound();
      }
    });
  }

  /// The public base URL encoded in a certificate QR code
  /// (`certificate_verification_base_url`). Null when the setting is absent.
  Future<String?> verificationBaseUrl() {
    return guard(() async {
      final row = await client
          .from('system_settings')
          .select('value')
          .eq('key', 'certificate_verification_base_url')
          .maybeSingle();
      final value = row?['value'];
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    });
  }

  /// Live updates to the caller's franchise records (RLS-scoped).
  Stream<List<FranchiseRecord>> watchMine() {
    return client
        .from('franchise_records')
        .stream(primaryKey: ['id'])
        .order('issued_at')
        .map((rows) => rows.map(FranchiseRecord.fromMap).toList());
  }

  static Map<String, dynamic>? _firstRow(dynamic data) {
    if (data is List) {
      if (data.isEmpty) return null;
      final first = data.first;
      return first is Map ? Map<String, dynamic>.from(first) : null;
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
