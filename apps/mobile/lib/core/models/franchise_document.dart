import '../constants.dart';

/// A submitted documentary requirement, mirroring `public.franchise_documents`.
///
/// Files themselves live in the private `franchise-documents` bucket; this
/// model only carries the metadata and the storage path used to request a
/// short-lived signed URL.
class FranchiseDocument {
  const FranchiseDocument({
    required this.id,
    required this.applicationId,
    required this.documentType,
    required this.storagePath,
    required this.fileName,
    this.fileSizeBytes,
    this.mimeType,
    this.verificationStatus = 'pending',
    this.remarks,
    this.uploadedAt,
    this.updatedAt,
  });

  final String id;
  final String applicationId;
  final String documentType;
  final String storagePath;
  final String fileName;
  final int? fileSizeBytes;
  final String? mimeType;

  /// `pending` | `verified` | `rejected`.
  final String verificationStatus;

  /// Staff remark, present when [verificationStatus] is `rejected`.
  final String? remarks;

  final DateTime? uploadedAt;
  final DateTime? updatedAt;

  bool get isVerified => verificationStatus == 'verified';

  bool get isRejected => verificationStatus == 'rejected';

  bool get isPending => verificationStatus == 'pending';

  /// Rejected or still-pending copies may be replaced; a verified copy is part
  /// of the reviewed record and is immutable (enforced by
  /// `rpc_driver_replace_document`).
  bool get canReplace => !isVerified;

  /// Human-readable label for the requirement.
  String get label => documentLabels[documentType] ?? documentType;

  /// Short label, safe for tiles and chips.
  String get shortLabel => documentShortLabels[documentType] ?? documentType;

  factory FranchiseDocument.fromMap(Map<String, dynamic> map) {
    return FranchiseDocument(
      id: (map['id'] ?? '').toString(),
      applicationId: (map['application_id'] ?? '').toString(),
      documentType: (map['document_type'] ?? '').toString(),
      storagePath: (map['storage_path'] ?? '').toString(),
      fileName: (map['file_name'] ?? '').toString(),
      fileSizeBytes: _asInt(map['file_size_bytes']),
      mimeType: map['mime_type']?.toString(),
      verificationStatus: (map['verification_status'] ?? 'pending').toString(),
      remarks: map['remarks']?.toString(),
      uploadedAt: _asDate(map['uploaded_at']),
      updatedAt: _asDate(map['updated_at']),
    );
  }
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
