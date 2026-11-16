import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/form_request.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';
import 'package:sbtf_mobile/core/models/franchise_record.dart';
import 'package:sbtf_mobile/core/models/profile.dart';
import 'package:sbtf_mobile/core/models/renewal_prefill.dart';
import 'package:sbtf_mobile/core/models/toda.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/features/application/application_form_screen.dart';
import 'package:sbtf_mobile/features/application/request_form_screen.dart';

void main() {
  const toda = Toda(id: 'toda-1', code: 'T1', name: 'Sto. Nino TODA');
  const barangay = Barangay(code: 'BR-1', name: 'Sto. Nino');
  const profile = Profile(
    id: 'profile-1',
    role: 'driver',
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    email: 'juan@example.com',
    contactNumber: '09171234567',
  );

  final record = FranchiseRecord(
    id: 'record-1',
    applicationId: 'application-1',
    operatorId: 'profile-1',
    todaId: 'toda-1',
    franchiseNumber: 'MTOP-2026-0001',
    verificationCode: 'ABC123',
    issuedAt: DateTime(2025, 3, 1),
    expiresAt: DateTime(2026, 3, 1),
    plateNumber: 'ABC 123',
    vehicleMake: 'Honda',
    vehicleModel: 'TMX',
    vehicleYear: 2019,
  );

  const application = FranchiseApplication(
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
    vehicleMake: 'Honda',
    vehicleModel: 'TMX 155',
    vehicleYear: 2020,
    vehicleColor: 'Blue',
    plateNumber: 'ABC 1234',
    engineNumber: 'ENG-12345',
    chassisNumber: 'CHS-12345',
    seatingCapacity: 6,
    ctcNumber: 'CTC-2026',
    appliedRoute: 'Mainaga - Poblacion',
    ownershipType: 'single_proprietorship',
    operatorCitizenship: 'Filipino',
  );

  const request = FormRequest(
    id: 'request-1',
    formNumber: 'REQ-2025-0001',
    requestedBy: 'profile-1',
    applicationType: ApplicationType.newFranchise,
    status: FormRequestStatus.converted,
    convertedApplicationId: 'application-1',
    ctcNumber: 'CTC-2026',
    crNumber: 'CR-9988',
  );

  final prefill = RenewalPrefill(
    record: record,
    application: application,
    request: request,
  );

  Widget harness(Widget screen, {List<FranchiseRecord>? records}) {
    return ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) => profile),
        todaListProvider.overrideWith((ref) => const <Toda>[toda]),
        barangayListProvider.overrideWith((ref) => const <Barangay>[barangay]),
        myRecordsProvider
            .overrideWith((ref) => records ?? <FranchiseRecord>[record]),
        renewalPrefillProvider.overrideWith((ref, id) => prefill),
      ],
      child: MaterialApp(home: screen),
    );
  }

  testWidgets('renewal with one franchise preselects it and fills the form',
      (tester) async {
    await tester.pumpWidget(
      harness(const ApplicationFormScreen(
          applicationType: ApplicationType.renewal)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Filled from franchise MTOP-2026-0001'),
        findsOneWidget);
    expect(find.text('Sto. Nino TODA'), findsOneWidget);
    expect(find.text('Sto. Nino'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Mainaga - Poblacion'), findsOneWidget);
    expect(find.text('Purok 2, San Teodoro'), findsOneWidget);
    expect(find.text('CTC-2026'), findsOneWidget);
  });

  testWidgets('request form renewal fills vehicle details from the franchise',
      (tester) async {
    await tester.pumpWidget(
      harness(const RequestFormScreen(initialType: ApplicationType.renewal)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Filled from franchise MTOP-2026-0001'),
        findsOneWidget);
    expect(find.text('MTOP-2026-0001 · ABC 123'), findsOneWidget);
    expect(find.text('Sto. Nino TODA'), findsOneWidget);
    // The CR number is only on the previous request, not on the application.
    await tester.scrollUntilVisible(
      find.text('CR-9988'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CR-9988'), findsOneWidget);
  });

  testWidgets('request form renewal with no franchise explains the choice',
      (tester) async {
    await tester.pumpWidget(
      harness(
        const RequestFormScreen(initialType: ApplicationType.renewal),
        records: const <FranchiseRecord>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('You have no franchise available to renew'),
      findsOneWidget,
    );
  });
}
