import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/form_request.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';
import 'package:sbtf_mobile/core/models/franchise_record.dart';
import 'package:sbtf_mobile/core/models/profile.dart';
import 'package:sbtf_mobile/core/models/toda.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/core/services/form_request_service.dart';
import 'package:sbtf_mobile/core/widgets/signature_pad.dart';
import 'package:sbtf_mobile/features/application/request_form_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A service that records what the screen uploads instead of calling Supabase.
class _FakeFormRequestService extends FormRequestService {
  _FakeFormRequestService()
      : super(SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final List<Uint8List> uploadedSignatures = <Uint8List>[];
  FormRequestSubmission? saved;

  @override
  Future<String> uploadSignature({
    required String profileId,
    required Uint8List bytes,
    String folder = 'form-requests',
    int? epochMillis,
  }) async {
    uploadedSignatures.add(bytes);
    return '$profileId/$folder/signature-test.png';
  }

  @override
  Future<FormRequest> updateRejected(
    String id,
    FormRequestSubmission submission,
  ) async {
    saved = submission;
    return _updatedRequest;
  }
}
const _profile = Profile(
  id: 'profile-1',
  role: 'driver',
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  email: 'juan@example.com',
  contactNumber: '09171234567',
);

const _toda = Toda(id: 'toda-1', code: 'T1', name: 'Sto. Nino TODA');

const _updatedRequest = FormRequest(
  id: 'request-1',
  formNumber: 'FR-2026-000012',
  requestedBy: 'profile-1',
  applicationType: ApplicationType.newFranchise,
  status: FormRequestStatus.requested,
  todaId: 'toda-1',
);

FormRequest _rejectedRequest({String? signatureStoragePath}) {
  return FormRequest(
    id: 'request-1',
    formNumber: 'FR-2026-000011',
    requestedBy: 'profile-1',
    applicationType: ApplicationType.newFranchise,
    status: FormRequestStatus.rejected,
    todaId: 'toda-1',
    rejectionReason: 'The plate number on the OR/CR is unreadable.',
    ctcNumber: 'CTC-2026',
    vehicleMake: 'Honda',
    vehicleModel: 'TMX 155',
    engineNumber: 'ENG-12345',
    chassisNumber: 'CHS-12345',
    plateNumber: 'ABC 1234',
    crNumber: 'CR-9988',
    orCrStoragePath: 'profile-1/form-requests/or-cr-old.pdf',
    orCrFileName: 'or-cr.pdf',
    orCrMimeType: 'application/pdf',
    orCrFileSizeBytes: 1024,
    signatureStoragePath: signatureStoragePath,
  );
}

void main() {
  _FakeFormRequestService newService() => _FakeFormRequestService();

  Widget harness(Widget screen, _FakeFormRequestService service) {
    return ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) => _profile),
        todaListProvider.overrideWith((ref) => const <Toda>[_toda]),
        myRecordsProvider.overrideWith((ref) => const <FranchiseRecord>[]),
        formRequestServiceProvider.overrideWithValue(service),
        openFormRequestProvider.overrideWith((ref) async => null),
        myFormRequestsProvider.overrideWith((ref) async => <FormRequest>[]),
        latestRejectedFormRequestProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(home: screen),
    );
  }

  Future<void> pumpForm(
    WidgetTester tester,
    _FakeFormRequestService service, {
    String? signatureStoragePath,
  }) async {
    await tester.pumpWidget(
      harness(
        RequestFormScreen(
          existing: _rejectedRequest(signatureStoragePath: signatureStoragePath),
        ),
        service,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, _FakeFormRequestService service) async {
    final button = find.text('Resubmit request');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(button);

    // Rasterising the drawing needs the real event loop, so alternate between
    // real time (for the engine) and pumps (for the service futures and the
    // rebuilds). `pumpAndSettle` is not used: the submit spinner animates
    // while the screen pops, and the success snackbar owns a timer.
    for (var i = 0; i < 300 && service.saved == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(service.saved, isNotNull,
        reason: 'the form reaches the service, not a validation dialog');
    await tester.pump(const Duration(seconds: 5));
  }

  Future<int> countOpaquePixels(WidgetTester tester, Uint8List bytes) async {
    final rgba = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = data?.buffer.asUint8List();
      image.dispose();
      codec.dispose();
      return pixels;
    });
    expect(rgba, isNotNull, reason: 'the uploaded PNG decodes');

    var opaque = 0;
    for (var index = 3; index < rgba!.length; index += 4) {
      if (rgba[index] != 0) opaque++;
    }
    return opaque;
  }

  testWidgets('resubmitting uploads the drawing instead of a blank pad',
      (tester) async {
    final service = newService();
    await pumpForm(tester, service);

    final pad = find.byType(SignaturePad);
    await tester.scrollUntilVisible(
      pad,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(pad, const Offset(70, 28));
    await tester.pumpAndSettle();

    await submit(tester, service);

    expect(service.saved, isNotNull,
        reason: 'the form reaches the service, not a validation dialog');
    expect(service.uploadedSignatures, hasLength(1));
    expect(
      service.uploadedSignatures.single.sublist(0, 8),
      <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      reason: 'the upload is a real PNG',
    );
    expect(
      await countOpaquePixels(tester, service.uploadedSignatures.single),
      greaterThan(0),
      reason: 'the uploaded PNG carries ink, not an empty pad',
    );
    expect(
      service.saved!.signatureStoragePath,
      'profile-1/form-requests/signature-test.png',
    );
    expect(service.saved!.signatureTypedName, isNull);
  });

  testWidgets('a rejected request keeps its drawn signature and says so',
      (tester) async {
    final service = newService();
    await pumpForm(
      tester,
      service,
      signatureStoragePath: 'profile-1/form-requests/signature-old.png',
    );

    final pad = find.byType(SignaturePad);
    await tester.scrollUntilVisible(
      pad,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('A signature is already on file'),
      findsOneWidget,
    );

    await submit(tester, service);

    expect(service.saved, isNotNull);
    expect(service.uploadedSignatures, isEmpty);
    expect(
      service.saved!.signatureStoragePath,
      'profile-1/form-requests/signature-old.png',
    );
  });

  testWidgets('a typed signature is sent when the driver does not draw',
      (tester) async {
    final service = newService();
    await pumpForm(tester, service);

    final typed = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'Your full name',
    );
    await tester.scrollUntilVisible(
      typed,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(typed, 'Juana Santos');
    await tester.pump();

    await submit(tester, service);

    expect(service.saved, isNotNull);
    expect(service.uploadedSignatures, isEmpty);
    expect(service.saved!.signatureTypedName, 'Juana Santos');
    expect(service.saved!.signatureStoragePath, isNull);
  });
}
