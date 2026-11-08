import '../constants.dart';
import 'franchise_application.dart';

/// Statuses of a pre-application form request. Mirrors
/// `public.form_request_status` after migration `20261106000000`.
abstract final class FormRequestStatus {
  static const String requested = 'requested';
  static const String issued = 'issued';
  static const String rejected = 'rejected';
  static const String converted = 'converted';
  static const String cancelled = 'cancelled';
}

/// One vehicle/franchise request form (`public.form_requests`).
///
/// A driver files this letter first; staff approve (issue) it, and only then
/// does `rpc_driver_submit_application` accept an application. The approved
/// request supplies the vehicle identity and the combined OR/CR file.
class FormRequest {
  const FormRequest({
    required this.id,
    required this.formNumber,
    required this.requestedBy,
    required this.applicationType,
    required this.status,
    this.todaId,
    this.purpose,
    this.requestedAt,
    this.issuedAt,
    this.issuedBy,
    this.convertedApplicationId,
    this.cancelledAt,
    this.cancelReason,
    this.applicantName,
    this.contactNumber,
    this.ctcNumber,
    this.ctcIssuedAt,
    this.ctcIssuedOn,
    this.vehicleMake,
    this.vehicleModel,
    this.engineNumber,
    this.chassisNumber,
    this.plateNumber,
    this.crNumber,
    this.orCrStoragePath,
    this.orCrFileName,
    this.orCrMimeType,
    this.orCrFileSizeBytes,
    this.signatureStoragePath,
    this.signatureTypedName,
    this.acknowledgedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.reviewDueAt,
    this.reviewReminderSentAt,
    this.reviewOverdueNotifiedAt,
    this.printedAt,
    this.printedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String formNumber;
  final String requestedBy;
  final String? todaId;
  final String applicationType;
  final String status;
  final String? purpose;
  final DateTime? requestedAt;
  final DateTime? issuedAt;
  final String? issuedBy;
  final String? convertedApplicationId;
  final DateTime? cancelledAt;
  final String? cancelReason;

  final String? applicantName;
  final String? contactNumber;
  final String? ctcNumber;
  final String? ctcIssuedAt;
  final DateTime? ctcIssuedOn;

  final String? vehicleMake;
  final String? vehicleModel;
  final String? engineNumber;
  final String? chassisNumber;
  final String? plateNumber;
  final String? crNumber;

  final String? orCrStoragePath;
  final String? orCrFileName;
  final String? orCrMimeType;
  final int? orCrFileSizeBytes;

  final String? signatureStoragePath;
  final String? signatureTypedName;

  final DateTime? acknowledgedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  /// Staff processing deadline. Not an expiry of an approved request.
  final DateTime? reviewDueAt;
  final DateTime? reviewReminderSentAt;
  final DateTime? reviewOverdueNotifiedAt;

  final DateTime? printedAt;
  final String? printedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isRequested => status == FormRequestStatus.requested;
  bool get isIssued => status == FormRequestStatus.issued;
  bool get isRejected => status == FormRequestStatus.rejected;
  bool get isConverted => status == FormRequestStatus.converted;
  bool get isCancelled => status == FormRequestStatus.cancelled;

  /// Still occupying the driver's one open request slot.
  bool get isOpen => isRequested || isIssued;

  bool get isRenewal => applicationType == ApplicationType.renewal;

  /// The review deadline has passed but staff have not acted yet.
  bool get isOverdue =>
      isRequested &&
      reviewDueAt != null &&
      DateTime.now().isAfter(reviewDueAt!);

  bool get hasOrCr =>
      orCrStoragePath != null && orCrStoragePath!.trim().isNotEmpty;

  String get vehicleLabel =>
      '${vehicleMake ?? ''} ${vehicleModel ?? ''}'.trim();

  factory FormRequest.fromMap(Map<String, dynamic> map) {
    return FormRequest(
      id: (map['id'] ?? '').toString(),
      formNumber: (map['form_number'] ?? '').toString(),
      requestedBy: (map['requested_by'] ?? '').toString(),
      todaId: map['toda_id']?.toString(),
      applicationType:
          (map['application_type'] ?? ApplicationType.newFranchise).toString(),
      status: (map['status'] ?? FormRequestStatus.requested).toString(),
      purpose: map['purpose']?.toString(),
      requestedAt: _asDate(map['requested_at']),
      issuedAt: _asDate(map['issued_at']),
      issuedBy: map['issued_by']?.toString(),
      convertedApplicationId: map['converted_application_id']?.toString(),
      cancelledAt: _asDate(map['cancelled_at']),
      cancelReason: map['cancel_reason']?.toString(),
      applicantName: map['applicant_name']?.toString(),
      contactNumber: map['contact_number']?.toString(),
      ctcNumber: map['ctc_number']?.toString(),
      ctcIssuedAt: map['ctc_issued_at']?.toString(),
      ctcIssuedOn: _asDate(map['ctc_issued_on']),
      vehicleMake: map['vehicle_make']?.toString(),
      vehicleModel: map['vehicle_model']?.toString(),
      engineNumber: map['engine_number']?.toString(),
      chassisNumber: map['chassis_number']?.toString(),
      plateNumber: map['plate_number']?.toString(),
      crNumber: map['cr_number']?.toString(),
      orCrStoragePath: map['or_cr_storage_path']?.toString(),
      orCrFileName: map['or_cr_file_name']?.toString(),
      orCrMimeType: map['or_cr_mime_type']?.toString(),
      orCrFileSizeBytes: _asInt(map['or_cr_file_size_bytes']),
      signatureStoragePath: map['signature_storage_path']?.toString(),
      signatureTypedName: map['signature_typed_name']?.toString(),
      acknowledgedAt: _asDate(map['acknowledged_at']),
      reviewedBy: map['reviewed_by']?.toString(),
      reviewedAt: _asDate(map['reviewed_at']),
      rejectionReason: map['rejection_reason']?.toString(),
      reviewDueAt: _asDate(map['review_due_at']),
      reviewReminderSentAt: _asDate(map['review_reminder_sent_at']),
      reviewOverdueNotifiedAt: _asDate(map['review_overdue_notified_at']),
      printedAt: _asDate(map['printed_at']),
      printedBy: map['printed_by']?.toString(),
      createdAt: _asDate(map['created_at']),
      updatedAt: _asDate(map['updated_at']),
    );
  }
}

/// The payload for `rpc_driver_request_form` and
/// `rpc_driver_update_form_request`.
class FormRequestSubmission {
  const FormRequestSubmission({
    required this.applicationType,
    required this.todaId,
    required this.ctcNumber,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.engineNumber,
    required this.chassisNumber,
    required this.plateNumber,
    required this.crNumber,
    required this.orCrStoragePath,
    required this.orCrFileName,
    required this.orCrMimeType,
    required this.orCrFileSizeBytes,
    this.purpose,
    this.signatureStoragePath,
    this.signatureTypedName,
  });

  final String applicationType;
  final String todaId;
  final String? purpose;
  final String ctcNumber;

  final String vehicleMake;
  final String vehicleModel;
  final String engineNumber;
  final String chassisNumber;
  final String plateNumber;
  final String crNumber;

  final String orCrStoragePath;
  final String orCrFileName;
  final String orCrMimeType;
  final int orCrFileSizeBytes;

  final String? signatureStoragePath;
  final String? signatureTypedName;

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'application_type': applicationType,
      'toda_id': todaId,
      'ctc_number': ctcNumber.trim(),
      'vehicle_make': vehicleMake.trim(),
      'vehicle_model': vehicleModel.trim(),
      'engine_number': engineNumber.trim(),
      'chassis_number': chassisNumber.trim(),
      'plate_number': plateNumber.trim(),
      'cr_number': crNumber.trim(),
      'or_cr_storage_path': orCrStoragePath,
      'or_cr_file_name': orCrFileName,
      'or_cr_mime_type': orCrMimeType,
      'or_cr_file_size_bytes': orCrFileSizeBytes,
    };

    void putIfPresent(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) payload[key] = value.trim();
    }

    putIfPresent('purpose', purpose);
    putIfPresent('signature_storage_path', signatureStoragePath);
    putIfPresent('signature_typed_name', signatureTypedName);
    return payload;
  }

  /// Client-side mirror of `fn_normalize_form_request_payload`.
  List<String> validate() {
    final problems = <String>[];

    if (applicationType != ApplicationType.newFranchise &&
        applicationType != ApplicationType.renewal) {
      problems.add('Choose whether this is a new or renewal franchise.');
    }
    if (todaId.trim().isEmpty) {
      problems.add('Select an accredited TODA.');
    }
    _require(problems, ctcNumber, 'CTC / Cedula number', 1, 40);
    _require(problems, vehicleMake, 'Vehicle make', 1, 60);
    _require(problems, vehicleModel, 'Vehicle model', 1, 60);
    _require(problems, engineNumber, 'Engine number', 3, 40);
    _require(problems, chassisNumber, 'Chassis number', 3, 40);
    _require(problems, plateNumber, 'Plate number', 3, 20);
    _require(problems, crNumber, 'CR number', 1, 60);

    if (orCrStoragePath.trim().isEmpty) {
      problems.add('Upload the combined OR/CR file.');
    }
    if (orCrMimeType.isNotEmpty &&
        !acceptedUploadMimeTypes.contains(orCrMimeType)) {
      problems.add('The OR/CR must be a PDF, JPEG or PNG file.');
    }
    if (orCrFileSizeBytes <= 0 || orCrFileSizeBytes > maxUploadBytes) {
      problems.add('The OR/CR must not exceed 10 MB.');
    }

    final hasSignature = (signatureStoragePath?.trim().isNotEmpty ?? false) ||
        (signatureTypedName?.trim().isNotEmpty ?? false);
    if (!hasSignature) {
      problems.add('Draw or type your signature.');
    }

    return problems;
  }

  static void _require(
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
