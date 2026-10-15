/// An issued franchise record (`public.franchise_records`).
///
/// Drivers read their own rows only; a record is created exclusively by the
/// staff approval RPC (`rpc_staff_approve_application`). The certificate file
/// lives in the private `certificates` bucket and is fetched through a
/// short-lived signed URL.
class FranchiseRecord {
  const FranchiseRecord({
    required this.id,
    required this.applicationId,
    required this.operatorId,
    required this.todaId,
    required this.franchiseNumber,
    required this.verificationCode,
    required this.issuedAt,
    required this.expiresAt,
    this.certificateStoragePath,
    this.certificateGeneratedAt,
    this.renewedByRecordId,
    this.archived = false,
    this.archivedAt,
    this.archiveReason,
    this.todaName,
    this.plateNumber,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.operatorName,
  });

  final String id;
  final String applicationId;
  final String operatorId;
  final String todaId;
  final String franchiseNumber;

  /// The opaque identifier embedded in the certificate QR code, resolved
  /// through `rpc_verify_certificate`. Contains no personal data.
  final String verificationCode;

  final DateTime issuedAt;
  final DateTime expiresAt;
  final String? certificateStoragePath;
  final DateTime? certificateGeneratedAt;
  final String? renewedByRecordId;
  final bool archived;
  final DateTime? archivedAt;
  final String? archiveReason;

  // Embedded (joined) fields, present when the query selects them.
  final String? todaName;
  final String? plateNumber;
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? operatorName;

  bool get hasCertificate =>
      certificateStoragePath != null && certificateStoragePath!.isNotEmpty;

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  /// Within 90 days of expiry (and not already expired/archived) — the reminder
  /// window defined by the scheduled `rpc_generate_renewal_reminders` job.
  bool get isExpiringSoon {
    if (isExpired || archived) return false;
    return expiresAt.difference(DateTime.now()).inDays <= 90;
  }

  /// Coarse state used for filtering and display:
  /// `archived` | `expired` | `expiring` | `active`.
  String get state {
    if (archived) return 'archived';
    if (isExpired) return 'expired';
    if (isExpiringSoon) return 'expiring';
    return 'active';
  }

  /// Whole days until expiry; negative once expired.
  int get daysRemaining => expiresAt.difference(DateTime.now()).inDays;

  String get vehicleDescription {
    final parts = <String>[
      if (vehicleMake != null && vehicleMake!.isNotEmpty) vehicleMake!,
      if (vehicleModel != null && vehicleModel!.isNotEmpty) vehicleModel!,
      if (vehicleYear != null) '($vehicleYear)',
    ];
    return parts.join(' ');
  }

  factory FranchiseRecord.fromMap(Map<String, dynamic> map) {
    final toda = map['toda'] ?? map['todas'];
    final operator = map['operator'] ?? map['profiles'];
    final application = map['application'] ?? map['franchise_applications'];

    return FranchiseRecord(
      id: (map['id'] ?? '').toString(),
      applicationId: (map['application_id'] ?? '').toString(),
      operatorId: (map['operator_id'] ?? '').toString(),
      todaId: (map['toda_id'] ?? '').toString(),
      franchiseNumber: (map['franchise_number'] ?? '').toString(),
      verificationCode: (map['verification_code'] ?? '').toString(),
      issuedAt: _asDate(map['issued_at']) ?? DateTime.now(),
      expiresAt: _asDate(map['expires_at']) ?? DateTime.now(),
      certificateStoragePath: map['certificate_storage_path']?.toString(),
      certificateGeneratedAt: _asDate(map['certificate_generated_at']),
      renewedByRecordId: map['renewed_by_record_id']?.toString(),
      archived: map['archived'] == true,
      archivedAt: _asDate(map['archived_at']),
      archiveReason: map['archive_reason']?.toString(),
      todaName: toda is Map ? toda['name']?.toString() : null,
      plateNumber:
          application is Map ? application['plate_number']?.toString() : null,
      vehicleMake:
          application is Map ? application['vehicle_make']?.toString() : null,
      vehicleModel:
          application is Map ? application['vehicle_model']?.toString() : null,
      vehicleYear:
          application is Map ? _asInt(application['vehicle_year']) : null,
      operatorName: operator is Map ? operator['full_name']?.toString() : null,
    );
  }
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
