import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/form_request.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';

FormRequestSubmission _submission({
  String type = ApplicationType.newFranchise,
  String todaId = 'toda-1',
  String ctc = 'CTC-123',
  String orCrPath = 'profile-1/form-requests/or-cr.pdf',
  String? signaturePath,
  String? typedSignature = 'Juan Dela Cruz',
}) {
  return FormRequestSubmission(
    applicationType: type,
    todaId: todaId,
    ctcNumber: ctc,
    vehicleMake: 'Honda',
    vehicleModel: 'TMX 155',
    engineNumber: 'ENG-123',
    chassisNumber: 'CHS-123',
    plateNumber: 'ABC 123',
    crNumber: 'CR-123',
    orCrStoragePath: orCrPath,
    orCrFileName: 'or-cr.pdf',
    orCrMimeType: 'application/pdf',
    orCrFileSizeBytes: 250000,
    signatureStoragePath: signaturePath,
    signatureTypedName: typedSignature,
  );
}

void main() {
  group('FormRequest.fromMap', () {
    test('reads the workflow fields and status helpers', () {
      final request = FormRequest.fromMap({
        'id': 'req-1',
        'form_number': 'FR-2026-000001',
        'requested_by': 'profile-1',
        'application_type': 'new',
        'status': 'rejected',
        'toda_id': 'toda-1',
        'rejection_reason': 'The OR/CR is blurry.',
        'vehicle_make': 'Honda',
        'plate_number': 'ABC 123',
        'engine_number': 'ENG-123',
        'chassis_number': 'CHS-123',
        'or_cr_storage_path': 'profile-1/form-requests/or-cr.pdf',
        'review_due_at': '2026-11-07T09:00:00Z',
        'printed_at': '2026-11-06T10:00:00Z',
      });

      expect(request.id, 'req-1');
      expect(request.formNumber, 'FR-2026-000001');
      expect(request.isRejected, isTrue);
      expect(request.isOpen, isFalse);
      expect(request.rejectionReason, 'The OR/CR is blurry.');
      expect(request.hasOrCr, isTrue);
      expect(request.vehicleLabel, 'Honda');
      expect(request.reviewDueAt, isNotNull);
      expect(request.printedAt, isNotNull);
    });

    test('a requested request is open and can be overdue', () {
      final request = FormRequest.fromMap({
        'id': 'req-2',
        'form_number': 'FR-2026-000002',
        'requested_by': 'profile-1',
        'application_type': 'renewal',
        'status': 'requested',
        'review_due_at': '2020-01-01T00:00:00Z',
      });

      expect(request.isRequested, isTrue);
      expect(request.isOpen, isTrue);
      expect(request.isRenewal, isTrue);
      expect(request.isOverdue, isTrue);
      expect(request.hasOrCr, isFalse);
    });
  });

  group('FormRequestSubmission.validate', () {
    test('accepts a complete new request with a typed signature', () {
      expect(_submission().validate(), isEmpty);
    });

    test('requires a CTC number', () {
      final problems = _submission(ctc: '  ').validate();
      expect(problems, contains('CTC / Cedula number is required.'));
    });

    test('requires a TODA', () {
      final problems = _submission(todaId: '').validate();
      expect(problems, contains('Select an accredited TODA.'));
    });

    test('requires one combined OR/CR file', () {
      final problems = _submission(orCrPath: '').validate();
      expect(problems, contains('Upload the combined OR/CR file.'));
    });

    test('requires either a drawn or a typed signature', () {
      final problems = _submission(typedSignature: null).validate();
      expect(problems, contains('Draw or type your signature.'));
    });

    test('a drawn signature satisfies the signature requirement', () {
      final problems = _submission(
        signaturePath: 'profile-1/form-requests/signature.png',
        typedSignature: null,
      ).validate();
      expect(problems, isEmpty);
    });

    test('rejects an unsupported OR/CR MIME type', () {
      final submission = FormRequestSubmission(
        applicationType: ApplicationType.newFranchise,
        todaId: 'toda-1',
        ctcNumber: 'CTC-123',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX 155',
        engineNumber: 'ENG-123',
        chassisNumber: 'CHS-123',
        plateNumber: 'ABC 123',
        crNumber: 'CR-123',
        orCrStoragePath: 'profile-1/form-requests/or-cr.zip',
        orCrFileName: 'or-cr.zip',
        orCrMimeType: 'application/zip',
        orCrFileSizeBytes: 250000,
        signatureTypedName: 'Juan Dela Cruz',
      );

      expect(
        submission.validate(),
        contains('The OR/CR must be a PDF, JPEG or PNG file.'),
      );
    });
  });

  group('FormRequestSubmission.toPayload', () {
    test('carries the normalised request fields', () {
      final payload = _submission().toPayload();

      expect(payload['application_type'], ApplicationType.newFranchise);
      expect(payload['toda_id'], 'toda-1');
      expect(payload['ctc_number'], 'CTC-123');
      expect(payload['plate_number'], 'ABC 123');
      expect(
          payload['or_cr_storage_path'], 'profile-1/form-requests/or-cr.pdf');
      expect(payload['signature_typed_name'], 'Juan Dela Cruz');
    });

    test('omits a blank optional purpose', () {
      final submission = FormRequestSubmission(
        applicationType: ApplicationType.newFranchise,
        todaId: 'toda-1',
        ctcNumber: 'CTC-123',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX 155',
        engineNumber: 'ENG-123',
        chassisNumber: 'CHS-123',
        plateNumber: 'ABC 123',
        crNumber: 'CR-123',
        purpose: '   ',
        orCrStoragePath: 'profile-1/form-requests/or-cr.pdf',
        orCrFileName: 'or-cr.pdf',
        orCrMimeType: 'application/pdf',
        orCrFileSizeBytes: 250000,
        signatureTypedName: 'Juan Dela Cruz',
      );

      expect(submission.toPayload().containsKey('purpose'), isFalse);
    });
  });
}
