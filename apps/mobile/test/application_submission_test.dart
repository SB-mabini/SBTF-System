import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/constants.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';

ApplicationDocumentUpload _upload(
  String type, {
  String path = 'profile-1/staging/file.pdf',
  String? mimeType = 'application/pdf',
  int? size = 1024,
}) {
  return ApplicationDocumentUpload(
    documentType: type,
    storagePath: path,
    fileName: 'file.pdf',
    mimeType: mimeType,
    fileSizeBytes: size,
  );
}

List<ApplicationDocumentUpload> _allDocuments() =>
    requiredDocumentTypes.map(_upload).toList();

ApplicationSubmission _valid(
    {String applicationType = ApplicationType.newFranchise}) {
  return ApplicationSubmission(
    applicationType: applicationType,
    todaId: 'toda-1',
    operatorFirstName: 'Juan',
    operatorMiddleName: 'Perez',
    operatorLastName: 'Dela Cruz',
    operatorContactNumber: '09171234567',
    operatorAddressLine: 'Purok 1, Barangay San Juan',
    vehicleMake: 'Honda',
    vehicleModel: 'TMX',
    vehicleYear: 2020,
    vehicleColor: 'Blue',
    plateNumber: 'ABC 123',
    engineNumber: 'ENG12345',
    chassisNumber: 'CHS12345',
    documents: _allDocuments(),
    renewalOfRecordId:
        applicationType == ApplicationType.renewal ? 'record-1' : null,
  );
}

void main() {
  group('ApplicationSubmission.validate', () {
    test('accepts a plausible new application', () {
      expect(_valid().validate(), isEmpty);
    });

    test('accepts a plausible renewal with its record id', () {
      expect(
          _valid(applicationType: ApplicationType.renewal).validate(), isEmpty);
    });

    test('requires the renewed record for a renewal', () {
      final submission = ApplicationSubmission(
        applicationType: ApplicationType.renewal,
        todaId: 'toda-1',
        operatorFirstName: 'Juan',
        operatorLastName: 'Dela Cruz',
        operatorContactNumber: '09171234567',
        operatorAddressLine: 'Purok 1, Barangay San Juan',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX',
        vehicleYear: 2020,
        vehicleColor: 'Blue',
        plateNumber: 'ABC 123',
        engineNumber: 'ENG12345',
        chassisNumber: 'CHS12345',
        documents: _allDocuments(),
      );

      expect(
        submission.validate(),
        contains('Select the franchise record being renewed.'),
      );
    });

    test('reports every missing documentary requirement', () {
      final submission = ApplicationSubmission(
        applicationType: ApplicationType.newFranchise,
        todaId: 'toda-1',
        operatorFirstName: 'Juan',
        operatorLastName: 'Dela Cruz',
        operatorContactNumber: '09171234567',
        operatorAddressLine: 'Purok 1, Barangay San Juan',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX',
        vehicleYear: 2020,
        vehicleColor: 'Blue',
        plateNumber: 'ABC 123',
        engineNumber: 'ENG12345',
        chassisNumber: 'CHS12345',
        documents: const [],
      );

      final problems = submission.validate();
      for (final type in requiredDocumentTypes) {
        expect(
          problems,
          contains('Missing documentary requirement: ${documentLabels[type]}.'),
        );
      }
    });

    test('rejects a document above the size limit', () {
      final documents = _allDocuments();
      documents[0] = _upload(
        requiredDocumentTypes.first,
        size: maxUploadBytes + 1,
      );
      final submission = ApplicationSubmission(
        applicationType: ApplicationType.newFranchise,
        todaId: 'toda-1',
        operatorFirstName: 'Juan',
        operatorLastName: 'Dela Cruz',
        operatorContactNumber: '09171234567',
        operatorAddressLine: 'Purok 1, Barangay San Juan',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX',
        vehicleYear: 2020,
        vehicleColor: 'Blue',
        plateNumber: 'ABC 123',
        engineNumber: 'ENG12345',
        chassisNumber: 'CHS12345',
        documents: documents,
      );

      expect(
        submission.validate(),
        contains(
          '${documentLabels[requiredDocumentTypes.first]} exceeds the 10 MB limit.',
        ),
      );
    });

    test('rejects an unsupported MIME type', () {
      final documents = _allDocuments();
      documents[0] = _upload(
        requiredDocumentTypes.first,
        mimeType: 'application/zip',
      );
      final submission = ApplicationSubmission(
        applicationType: ApplicationType.newFranchise,
        todaId: 'toda-1',
        operatorFirstName: 'Juan',
        operatorLastName: 'Dela Cruz',
        operatorContactNumber: '09171234567',
        operatorAddressLine: 'Purok 1, Barangay San Juan',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX',
        vehicleYear: 2020,
        vehicleColor: 'Blue',
        plateNumber: 'ABC 123',
        engineNumber: 'ENG12345',
        chassisNumber: 'CHS12345',
        documents: documents,
      );

      expect(
        submission.validate(),
        contains(
          '${documentLabels[requiredDocumentTypes.first]} must be a PDF, JPEG or PNG file.',
        ),
      );
    });

    test('rejects a vehicle year outside the plausible range', () {
      final submission = ApplicationSubmission(
        applicationType: ApplicationType.newFranchise,
        todaId: 'toda-1',
        operatorFirstName: 'Juan',
        operatorLastName: 'Dela Cruz',
        operatorContactNumber: '09171234567',
        operatorAddressLine: 'Purok 1, Barangay San Juan',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX',
        vehicleYear: 1900,
        vehicleColor: 'Blue',
        plateNumber: 'ABC 123',
        engineNumber: 'ENG12345',
        chassisNumber: 'CHS12345',
        documents: _allDocuments(),
      );

      expect(
        submission
            .validate()
            .any((problem) => problem.startsWith('Vehicle year')),
        isTrue,
      );
    });
  });

  group('ApplicationSubmission.toPayload', () {
    test('carries the required keys and the document list', () {
      final payload = _valid().toPayload();

      expect(payload['application_type'], ApplicationType.newFranchise);
      expect(payload['toda_id'], 'toda-1');
      expect(payload['operator_first_name'], 'Juan');
      expect(payload['operator_last_name'], 'Dela Cruz');
      expect(payload['vehicle_year'], 2020);
      expect(payload['seating_capacity'], 5);
      expect(payload['documents'], hasLength(requiredDocumentTypes.length));
      expect((payload['documents'] as List).first, isA<Map<String, dynamic>>());
    });

    test('trims present optional fields', () {
      final submission = ApplicationSubmission(
        applicationType: ApplicationType.newFranchise,
        todaId: 'toda-1',
        operatorFirstName: 'Juan',
        operatorLastName: 'Dela Cruz',
        operatorContactNumber: '09171234567',
        operatorAddressLine: 'Purok 1',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX',
        vehicleYear: 2020,
        vehicleColor: 'Blue',
        plateNumber: 'ABC 123',
        engineNumber: 'ENG12345',
        chassisNumber: 'CHS12345',
        remarks: '  For review  ',
        documents: _allDocuments(),
      );

      expect(submission.toPayload()['remarks'], 'For review');
    });

    test('omits optional fields that are null or blank', () {
      final payload = ApplicationSubmission(
        applicationType: ApplicationType.newFranchise,
        todaId: 'toda-1',
        operatorFirstName: 'Juan',
        operatorLastName: 'Dela Cruz',
        operatorContactNumber: '09171234567',
        operatorAddressLine: 'Purok 1',
        vehicleMake: 'Honda',
        vehicleModel: 'TMX',
        vehicleYear: 2020,
        vehicleColor: 'Blue',
        plateNumber: 'ABC 123',
        engineNumber: 'ENG12345',
        chassisNumber: 'CHS12345',
        operatorEmail: '   ',
        documents: _allDocuments(),
      ).toPayload();

      expect(payload.containsKey('operator_middle_name'), isFalse);
      expect(payload.containsKey('operator_email'), isFalse);
      expect(payload.containsKey('mtop_number'), isFalse);
      expect(payload.containsKey('renewal_of_record_id'), isFalse);
    });

    test('includes renewal_of_record_id only for a renewal', () {
      final renewal =
          _valid(applicationType: ApplicationType.renewal).toPayload();

      expect(renewal['renewal_of_record_id'], 'record-1');
      expect(_valid().toPayload().containsKey('renewal_of_record_id'), isFalse);
    });
  });
}
