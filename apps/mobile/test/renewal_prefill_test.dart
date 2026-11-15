import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/form_request.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';
import 'package:sbtf_mobile/core/models/franchise_record.dart';
import 'package:sbtf_mobile/core/models/renewal_prefill.dart';

FranchiseRecord _record() {
  return FranchiseRecord(
    id: 'record-1',
    applicationId: 'application-1',
    operatorId: 'profile-1',
    todaId: 'toda-1',
    franchiseNumber: 'SBTF-2026-0001',
    verificationCode: 'ABC123',
    issuedAt: DateTime(2025, 3, 1),
    expiresAt: DateTime(2026, 3, 1),
    plateNumber: 'ABC 123',
    vehicleMake: 'Honda',
    vehicleModel: 'TMX',
    vehicleYear: 2019,
  );
}

FranchiseApplication _application() {
  return const FranchiseApplication(
    id: 'application-1',
    applicationNumber: 'APP-2025-0001',
    applicantId: 'profile-1',
    applicationType: ApplicationType.newFranchise,
    status: ApplicationStatus.approved,
    todaId: 'toda-1',
    operatorFirstName: 'Juan',
    operatorLastName: 'Dela Cruz',
    operatorContactNumber: '09171234567',
    operatorAddressLine: 'Purok 2, San Teodoro',
    operatorBarangayCode: 'BR-1',
    operatorEmail: 'juan@example.com',
    vehicleMake: 'Honda',
    vehicleModel: 'TMX 155',
    vehicleYear: 2020,
    vehicleColor: 'Blue',
    plateNumber: 'ABC 1234',
    engineNumber: 'ENG-12345',
    chassisNumber: 'CHS-12345',
    seatingCapacity: 6,
    mtopNumber: 'MTOP-9',
    bodyNumber: 'BODY-9',
    ctcNumber: 'CTC-2026',
    appliedRoute: 'Mainaga - Poblacion',
    registeredOwner: 'Juan Dela Cruz',
    ownershipType: 'single_proprietorship',
    operatorCitizenship: 'Filipino',
  );
}

FormRequest _request() {
  return const FormRequest(
    id: 'request-1',
    formNumber: 'REQ-2025-0001',
    requestedBy: 'profile-1',
    applicationType: ApplicationType.newFranchise,
    status: FormRequestStatus.converted,
    convertedApplicationId: 'application-1',
    todaId: 'toda-1',
    ctcNumber: 'CTC-2025',
    crNumber: 'CR-9988',
    vehicleMake: 'Honda',
    vehicleModel: 'TMX',
    engineNumber: 'ENG-OLD',
    chassisNumber: 'CHS-OLD',
    plateNumber: 'ABC 123',
  );
}

void main() {
  group('RenewalPrefill', () {
    test('prefers the application, then the request, then the record', () {
      final prefill = RenewalPrefill(
        record: _record(),
        application: _application(),
        request: _request(),
      );

      expect(prefill.franchiseNumber, 'SBTF-2026-0001');
      expect(prefill.purpose, 'Renewal of franchise SBTF-2026-0001');
      expect(prefill.plateNumber, 'ABC 1234');
      expect(prefill.vehicleModel, 'TMX 155');
      expect(prefill.engineNumber, 'ENG-12345');
      expect(prefill.crNumber, 'CR-9988');
      expect(prefill.ctcNumber, 'CTC-2026');
      expect(prefill.vehicleYear, 2020);
      expect(prefill.appliedRoute, 'Mainaga - Poblacion');
      expect(prefill.barangayCode, 'BR-1');
      expect(prefill.registeredOwner, 'Juan Dela Cruz');
      expect(prefill.ownershipType, 'single_proprietorship');
      expect(prefill.citizenship, 'Filipino');
      expect(prefill.seatingCapacity, 6);
      expect(prefill.hasVehicleIdentity, isTrue);
    });

    test('falls back to the record when the application is unreadable', () {
      final prefill = RenewalPrefill(record: _record());

      expect(prefill.plateNumber, 'ABC 123');
      expect(prefill.vehicleMake, 'Honda');
      expect(prefill.vehicleModel, 'TMX');
      expect(prefill.vehicleYear, 2019);
      expect(prefill.engineNumber, isEmpty);
      expect(prefill.crNumber, isEmpty);
      expect(prefill.ctcNumber, isEmpty);
      expect(prefill.purpose, contains('SBTF-2026-0001'));
      expect(prefill.addressLine, isEmpty);
      expect(prefill.appliedRoute, isEmpty);
      expect(prefill.ownershipType, 'single_proprietorship');
      expect(prefill.citizenship, 'Filipino');
    });

    test('uses the request vehicle fields when the application is absent', () {
      final prefill = RenewalPrefill(
        record: _record(),
        request: _request(),
      );

      expect(prefill.plateNumber, 'ABC 123');
      expect(prefill.vehicleModel, 'TMX');
      expect(prefill.engineNumber, 'ENG-OLD');
      expect(prefill.chassisNumber, 'CHS-OLD');
      expect(prefill.ctcNumber, 'CTC-2025');
      expect(prefill.crNumber, 'CR-9988');
      expect(prefill.hasVehicleIdentity, isTrue);
    });

    test('ignores blank stored strings instead of filling empty values', () {
      final prefill = RenewalPrefill(
        record: _record(),
        request: const FormRequest(
          id: 'request-2',
          formNumber: 'REQ-2',
          requestedBy: 'profile-1',
          applicationType: ApplicationType.renewal,
          status: FormRequestStatus.converted,
          ctcNumber: '   ',
          crNumber: '',
        ),
      );

      expect(prefill.ctcNumber, isEmpty);
      expect(prefill.crNumber, isEmpty);
    });
  });
}
