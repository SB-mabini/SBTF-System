import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    List<Barangay> barangays = const <Barangay>[barangay],
    List<Toda> todas = const <Toda>[toda],
  }) {
    return ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) => profile),
        todaListProvider.overrideWith((ref) => todas),
        barangayListProvider.overrideWith((ref) => barangays),
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

  testWidgets('TODA and barangay labels sit above their placeholder text',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      tester.getBottomLeft(find.text('TODA')).dy,
      lessThan(tester.getTopLeft(find.text('Select your TODA')).dy),
    );
    expect(
      tester.getBottomLeft(find.text('Barangay')).dy,
      lessThan(tester.getTopLeft(find.text('Select your barangay')).dy),
    );
  });

  testWidgets('TODA picker opens from the bottom and remains selectable',
      (tester) async {
    const todas = <Toda>[
      Toda(id: 'toda-3', code: 'T3', name: 'Talaga Proper TODA'),
      toda,
      Toda(id: 'toda-2', code: 'T2', name: 'San Teodoro TODA'),
    ];
    await tester.pumpWidget(harness(todas: todas));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select your TODA'));
    await tester.pumpAndSettle();

    final sheetTitle = find.text('Choose your TODA');
    expect(sheetTitle, findsOneWidget);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isFalse,
    );
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getTopLeft(sheetTitle).dy, greaterThan(logicalHeight * 0.25));

    final option = find.text('Sto. Nino TODA');
    expect(option, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(option).text.style?.fontSize,
      13,
    );
    final alphabeticalOptions = [
      'San Teodoro TODA',
      'Sto. Nino TODA',
      'Talaga Proper TODA',
    ];
    final optionPositions = alphabeticalOptions
        .map((name) => tester.getTopLeft(find.text(name)).dy)
        .toList();
    expect(optionPositions, orderedEquals([...optionPositions]..sort()));

    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Sto. Nino TODA'), findsOneWidget);
  });

  testWidgets('barangay picker opens from the bottom and remains selectable',
      (tester) async {
    const barangays = <Barangay>[
      Barangay(code: 'BR-2', name: 'Talaga Proper'),
      barangay,
      Barangay(code: 'BR-3', name: 'Talaga East'),
      Barangay(code: 'BR-4', name: 'San Teodoro'),
    ];
    await tester.pumpWidget(harness(barangays: barangays));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select your barangay'));
    await tester.pumpAndSettle();

    final sheetTitle = find.text('Choose your barangay');
    expect(sheetTitle, findsOneWidget);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isFalse,
    );
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getTopLeft(sheetTitle).dy, greaterThan(logicalHeight * 0.25));

    final option = find.text('Sto. Nino');
    expect(option, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(option).text.style?.fontSize,
      13,
    );
    final alphabeticalOptions = [
      'San Teodoro',
      'Sto. Nino',
      'Talaga East',
      'Talaga Proper',
    ];
    final optionPositions = alphabeticalOptions
        .map((name) => tester.getTopLeft(find.text(name)).dy)
        .toList();
    expect(optionPositions, orderedEquals([...optionPositions]..sort()));

    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Sto. Nino'), findsOneWidget);
  });

  testWidgets('a renewal with no record explains why it cannot continue',
      (tester) async {
    await tester.pumpWidget(harness(type: ApplicationType.renewal));
    await tester.pumpAndSettle();

    expect(find.text('Renewal application'), findsOneWidget);
    expect(find.text('No franchise available to renew'), findsOneWidget);
  });
}
