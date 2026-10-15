import '../constants.dart';
import 'application_event.dart';
import 'franchise_document.dart';

/// Which kind of application is being filed. Mirrors `public.application_type`.
abstract final class ApplicationType {
  static const String newFranchise = 'new';
  static const String renewal = 'renewal';
}

/// The fixed workflow states. Mirrors `public.application_status`.
abstract final class ApplicationStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// One documentary requirement as it is uploaded *before* submission.
///
/// The file must already live in the caller's own storage folder; the database
/// re-checks that prefix (`storage_path like '{profile_id}/%'`) and rejects
/// anything else.
class ApplicationDocumentUpload {
  const ApplicationDocumentUpload({
    required this.documentType,
    required this.storagePath,
    required this.fileName,
    this.fileSizeBytes,
    this.mimeType,
  });

  final String documentType;
  final String storagePath;
  final String fileName;
  final int? fileSizeBytes;
  final String? mimeType;

  Map<String, dynamic> toMap() {
    return {
      'document_type': documentType,
      'storage_path': storagePath,
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
    };
  }
}

/// The complete payload for `rpc_driver_submit_application`.
///
/// Building it here (rather than hand-rolling a map at the call site) keeps the
/// JSON keys identical to the migration and makes the field rules testable
/// without a database.
class ApplicationSubmission {
  const ApplicationSubmission({
    required this.applicationType,
    required this.todaId,
    required this.operatorFirstName,
    required this.operatorLastName,
    required this.operatorContactNumber,
    required this.operatorAddressLine,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleColor,
    required this.plateNumber,
    required this.engineNumber,
    required this.chassisNumber,
    required this.documents,
    this.operatorMiddleName,
    this.operatorBarangayCode,
    this.operatorEmail,
    this.seatingCapacity = 5,
    this.mtopNumber,
    this.bodyNumber,
    this.renewalOfRecordId,
    this.remarks,
  });

  final String applicationType;
  final String todaId;

  final String operatorFirstName;
  final String? operatorMiddleName;
  final String operatorLastName;
  final String operatorContactNumber;
  final String operatorAddressLine;
  final String? operatorBarangayCode;
  final String? operatorEmail;

  final String vehicleMake;
  final String vehicleModel;
  final int vehicleYear;
  final String vehicleColor;
  final String plateNumber;
  final String engineNumber;
  final String chassisNumber;
  final int seatingCapacity;
  final String? mtopNumber;
  final String? bodyNumber;

  /// Set only for a renewal: the franchise record being renewed.
  final String? renewalOfRecordId;

  final String? remarks;

  final List<ApplicationDocumentUpload> documents;

  bool get isRenewal => applicationType == ApplicationType.renewal;

  /// The exact `jsonb` argument the RPC expects.
  ///
  /// Optional fields are omitted when empty so `fn_optional_text` sees them as
  /// absent rather than an empty string (which it would reject).
  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'application_type': applicationType,
      'toda_id': todaId,
      'operator_first_name': operatorFirstName,
      'operator_last_name': operatorLastName,
      'operator_contact_number': operatorContactNumber,
      'operator_address_line': operatorAddressLine,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'plate_number': plateNumber,
      'engine_number': engineNumber,
      'chassis_number': chassisNumber,
      'seating_capacity': seatingCapacity,
      'documents': documents.map((document) => document.toMap()).toList(),
    };

    void putIfPresent(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) payload[key] = value.trim();
    }

    putIfPresent('operator_middle_name', operatorMiddleName);
    putIfPresent('operator_barangay_code', operatorBarangayCode);
    putIfPresent('operator_email', operatorEmail);
    putIfPresent('mtop_number', mtopNumber);
    putIfPresent('body_number', bodyNumber);
    putIfPresent('remarks', remarks);
    if (isRenewal && renewalOfRecordId != null) {
      payload['renewal_of_record_id'] = renewalOfRecordId;
    }

    return payload;
  }

  /// Client-side pre-validation, mirroring the server rules in
  /// `rpc_driver_submit_application` so the form can refuse bad input before a
  /// network call. The server remains the authority; this only improves the
  /// experience.
  ///
  /// Returns an empty list when the submission is plausible.
  List<String> validate() {
    final problems = <String>[];

    if (applicationType != ApplicationType.newFranchise &&
        applicationType != ApplicationType.renewal) {
      problems.add('Choose whether this is a new or renewal application.');
    }
    if (todaId.trim().isEmpty) {
      problems.add('Select an accredited TODA.');
    }
    if (isRenewal &&
        (renewalOfRecordId == null || renewalOfRecordId!.isEmpty)) {
      problems.add('Select the franchise record being renewed.');
    }

    _requireText(problems, operatorFirstName, 'First name', 1, 80);
    _requireText(problems, operatorLastName, 'Last name', 1, 80);
    _requireText(problems, operatorContactNumber, 'Contact number', 7, 20);
    _requireText(problems, operatorAddressLine, 'Address', 5, 200);
    _requireText(problems, vehicleMake, 'Vehicle make', 1, 60);
    _requireText(problems, vehicleModel, 'Vehicle model', 1, 60);
    _requireText(problems, vehicleColor, 'Vehicle color', 2, 40);
    _requireText(problems, plateNumber, 'Plate number', 3, 20);
    _requireText(problems, engineNumber, 'Engine number', 3, 40);
    _requireText(problems, chassisNumber, 'Chassis number', 3, 40);
    _optionalText(problems, operatorMiddleName, 'Middle name', 80);
    _optionalText(problems, operatorEmail, 'E-mail', 160);
    _optionalText(problems, mtopNumber, 'MTOP number', 60);
    _optionalText(problems, bodyNumber, 'Body number', 60);
    _optionalText(problems, remarks, 'Remarks', 1000);

    final year = DateTime.now().year;
    if (vehicleYear < 1950 || vehicleYear > year + 1) {
      problems.add('Vehicle year must be between 1950 and ${year + 1}.');
    }
    if (seatingCapacity < 1 || seatingCapacity > 12) {
      problems.add('Seating capacity must be between 1 and 12.');
    }

    final providedTypes =
        documents.map((document) => document.documentType).toSet();
    for (final type in requiredDocumentTypes) {
      if (!providedTypes.contains(type)) {
        problems.add(
            'Missing documentary requirement: ${documentLabels[type] ?? type}.');
      }
    }
    for (final document in documents) {
      if (document.storagePath.trim().isEmpty) {
        problems.add(
            '${documentLabels[document.documentType] ?? document.documentType} '
            'has no uploaded file.');
      }
      if (document.mimeType != null &&
          !acceptedUploadMimeTypes.contains(document.mimeType)) {
        problems.add(
            '${documentLabels[document.documentType] ?? document.documentType} '
            'must be a PDF, JPEG or PNG file.');
      }
      if (document.fileSizeBytes != null &&
          document.fileSizeBytes! > maxUploadBytes) {
        problems.add(
            '${documentLabels[document.documentType] ?? document.documentType} '
            'exceeds the 10 MB limit.');
      }
    }

    return problems;
  }
}

void _requireText(
  List<String> problems,
  String value,
  String label,
  int min,
  int max,
) {
  final length = value.trim().length;
  if (length < min) {
    problems.add('$label is required.');
  } else if (length > max) {
    problems.add('$label must not exceed $max characters.');
  }
}

void _optionalText(
  List<String> problems,
  String? value,
  String label,
  int max,
) {
  if (value != null && value.trim().length > max) {
    problems.add('$label must not exceed $max characters.');
  }
}

/// A franchise application row (`public.franchise_applications`), optionally
/// carrying the TODA, documents and timeline when selected with their
/// relationships.
class FranchiseApplication {
  const FranchiseApplication({
    required this.id,
    required this.applicationNumber,
    required this.applicantId,
    required this.applicationType,
    required this.status,
    required this.todaId,
    required this.operatorFirstName,
    required this.operatorLastName,
    required this.operatorContactNumber,
    required this.operatorAddressLine,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleColor,
    required this.plateNumber,
    required this.engineNumber,
    required this.chassisNumber,
    required this.seatingCapacity,
    this.operatorMiddleName,
    this.operatorBarangayCode,
    this.operatorEmail,
    this.mtopNumber,
    this.bodyNumber,
    this.renewalOfRecordId,
    this.remarks,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
    this.todaName,
    this.documents = const [],
    this.timeline = const [],
  });

  final String id;
  final String applicationNumber;
  final String applicantId;
  final String applicationType;
  final String status;
  final String todaId;

  final String operatorFirstName;
  final String? operatorMiddleName;
  final String operatorLastName;
  final String operatorContactNumber;
  final String operatorAddressLine;
  final String? operatorBarangayCode;
  final String? operatorEmail;

  final String vehicleMake;
  final String vehicleModel;
  final int vehicleYear;
  final String vehicleColor;
  final String plateNumber;
  final String engineNumber;
  final String chassisNumber;
  final int seatingCapacity;
  final String? mtopNumber;
  final String? bodyNumber;

  final String? renewalOfRecordId;
  final String? remarks;

  /// Present when [status] is `rejected`.
  final String? rejectionReason;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Resolved TODA name, when the row was selected with its TODA relation.
  final String? todaName;

  final List<FranchiseDocument> documents;

  /// Timeline entries, when the row was selected with its history relation.
  final List<ApplicationEvent> timeline;

  bool get isPending => status == ApplicationStatus.pending;

  bool get isApproved => status == ApplicationStatus.approved;

  bool get isRejected => status == ApplicationStatus.rejected;

  bool get isRenewal => applicationType == ApplicationType.renewal;

  String get operatorFullName {
    final parts = <String>[
      operatorFirstName,
      if (operatorMiddleName != null && operatorMiddleName!.trim().isNotEmpty)
        operatorMiddleName!,
      operatorLastName,
    ].where((part) => part.trim().isNotEmpty);
    return parts.join(' ');
  }

  /// Documents in the canonical requirement order, so the UI never depends on
  /// the order PostgREST happens to return.
  List<FranchiseDocument> get orderedDocuments {
    final ordered = [...documents];
    ordered.sort((a, b) {
      final indexA = requiredDocumentTypes.indexOf(a.documentType);
      final indexB = requiredDocumentTypes.indexOf(b.documentType);
      return (indexA < 0 ? 99 : indexA).compareTo(indexB < 0 ? 99 : indexB);
    });
    return ordered;
  }

  /// Timeline entries oldest-first, matching how the tracker renders them.
  List<ApplicationEvent> get orderedTimeline {
    final ordered = [...timeline];
    ordered.sort((a, b) {
      final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB);
    });
    return ordered;
  }

  factory FranchiseApplication.fromMap(Map<String, dynamic> map) {
    final toda = map['toda'] ?? map['todas'];
    final documents = map['documents'] ?? map['franchise_documents'];
    final timeline = map['timeline'] ?? map['application_status_history'];

    return FranchiseApplication(
      id: (map['id'] ?? '').toString(),
      applicationNumber: (map['application_number'] ?? '').toString(),
      applicantId: (map['applicant_id'] ?? '').toString(),
      applicationType:
          (map['application_type'] ?? ApplicationType.newFranchise).toString(),
      status: (map['status'] ?? ApplicationStatus.pending).toString(),
      todaId: (map['toda_id'] ?? '').toString(),
      operatorFirstName: (map['operator_first_name'] ?? '').toString(),
      operatorMiddleName: map['operator_middle_name']?.toString(),
      operatorLastName: (map['operator_last_name'] ?? '').toString(),
      operatorContactNumber: (map['operator_contact_number'] ?? '').toString(),
      operatorAddressLine: (map['operator_address_line'] ?? '').toString(),
      operatorBarangayCode: map['operator_barangay_code']?.toString(),
      operatorEmail: map['operator_email']?.toString(),
      vehicleMake: (map['vehicle_make'] ?? '').toString(),
      vehicleModel: (map['vehicle_model'] ?? '').toString(),
      vehicleYear: _asInt(map['vehicle_year']) ?? 0,
      vehicleColor: (map['vehicle_color'] ?? '').toString(),
      plateNumber: (map['plate_number'] ?? '').toString(),
      engineNumber: (map['engine_number'] ?? '').toString(),
      chassisNumber: (map['chassis_number'] ?? '').toString(),
      seatingCapacity: _asInt(map['seating_capacity']) ?? 5,
      mtopNumber: map['mtop_number']?.toString(),
      bodyNumber: map['body_number']?.toString(),
      renewalOfRecordId: map['renewal_of_record_id']?.toString(),
      remarks: map['remarks']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
      submittedAt: _asDate(map['submitted_at']),
      reviewedAt: _asDate(map['reviewed_at']),
      createdAt: _asDate(map['created_at']),
      updatedAt: _asDate(map['updated_at']),
      todaName: toda is Map ? toda['name']?.toString() : null,
      documents: documents is List
          ? documents
              .whereType<Map>()
              .map((row) =>
                  FranchiseDocument.fromMap(row.cast<String, dynamic>()))
              .toList()
          : const [],
      timeline: timeline is List
          ? timeline
              .whereType<Map>()
              .map((row) =>
                  ApplicationEvent.fromMap(row.cast<String, dynamic>()))
              .toList()
          : const [],
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
