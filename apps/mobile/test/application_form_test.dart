import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';
import 'package:sbtf_mobile/core/models/franchise_record.dart';
import 'package:sbtf_mobile/core/models/profile.dart';
import 'package:sbtf_mobile/core/models/toda.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/features/application/application_form_screen.dart';

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

  Widget harness({
    String type = ApplicationType.newFranchise,
    List<FranchiseRecord> records = const <FranchiseRecord>[],
  }) {
    return ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) => profile),
        todaListProvider.overrideWith((ref) => <Toda>[toda]),
        barangayListProvider.overrideWith((ref) => <Barangay>[barangay]),
        myRecordsProvider.overrideWith((ref) => records),
      ],
      child: MaterialApp(
        home: ApplicationFormScreen(applicationType: type),
      ),
    );
  }

  testWidgets('opens on the requested application type', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('New application'), findsOneWidget);
    expect(find.text('New franchise'), findsOneWidget);
    expect(find.text('Renewal'), findsOneWidget);
    expect(find.text('Select your TODA'), findsOneWidget);
  });

  testWidgets('blocks Next until a TODA is chosen', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Select an accredited TODA.'), findsOneWidget);
    // Still on the first step.
    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
  });

  testWidgets('a renewal with no record explains why it cannot continue',
      (tester) async {
    await tester.pumpWidget(harness(type: ApplicationType.renewal));
    await tester.pumpAndSettle();

    expect(find.text('Renewal application'), findsOneWidget);
    expect(find.text('No franchise available to renew'), findsOneWidget);
  });
}
