import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/constants.dart';
import 'package:sbtf_mobile/core/document_picker.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';
import 'package:sbtf_mobile/core/models/franchise_document.dart';
import 'package:sbtf_mobile/core/models/profile.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/core/services/document_service.dart';
import 'package:sbtf_mobile/features/documents/application_documents_screen.dart';
import 'package:sbtf_mobile/features/documents/document_manager_screen.dart';

const _profile = Profile(
  id: 'profile-1',
  role: 'driver',
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  email: 'juan@example.com',
  contactNumber: '09171234567',
);

FranchiseApplication _application({
  required String status,
  required List<Map<String, dynamic>> documents,
}) {
  return FranchiseApplication.fromMap({
    'id': 'app-1',
    'application_number': 'SBTF-2026-0001',
    'status': status,
    'submitted_at': '2026-09-01T00:00:00Z',
    'documents': documents,
  });
}

Map<String, dynamic> _doc(
  String type, {
  String verification = 'pending',
  String? remarks,
  String mimeType = 'application/pdf',
  String fileName = 'file.pdf',
}) {
  return {
    'id': 'doc-$type',
    'application_id': 'app-1',
    'document_type': type,
    'verification_status': verification,
    'remarks': remarks,
    'mime_type': mimeType,
    'file_name': fileName,
    'storage_path': 'profile-1/app-1/$type.pdf',
    'uploaded_at': '2026-09-01T00:00:00Z',
  };
}

/// A pending application whose OR/CR was rejected, one requirement still
/// pending, and two verified.
FranchiseApplication _mixedPending() => _application(
      status: ApplicationStatus.pending,
      documents: [
        _doc('member_association_certificate'),
        _doc('or_cr',
            verification: 'rejected', remarks: 'The OR/CR is blurred.'),
        _doc('cedula', verification: 'verified'),
        _doc('barangay_clearance', verification: 'verified'),
      ],
    );

FranchiseApplication _approvedAllVerified() => _application(
      status: ApplicationStatus.approved,
      documents: [
        for (final type in requiredDocumentTypes)
          _doc(type, verification: 'verified'),
      ],
    );

class _FakePicker implements DocumentPicker {
  _FakePicker(this.result);

  final PickedDocument? result;
  int calls = 0;

  @override
  Future<PickedDocument?> pick() async {
    calls++;
    return result;
  }
}

/// A stand-in for [DocumentService] that records the calls the screen makes.
///
/// It deliberately does *not* extend [DocumentService]: constructing the real
/// service builds a `SupabaseClient`, which starts a background auth-refresh
/// timer that a widget test would then report as a leak. Only the three members
/// the screen touches are implemented; any other call is a bug in the screen,
/// so it fails loudly through [noSuchMethod].
class _RecordingDocumentService implements DocumentService {
  final List<String> uploadedDocumentTypes = <String>[];
  final List<String> replacedDocumentIds = <String>[];
  String? lastStoragePath;
  String? signedUrlResult = 'https://example.supabase.co/storage/signed/file';

  @override
  Future<String> uploadDocument({
    required String profileId,
    required String documentType,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? applicationId,
    int? epochMillis,
  }) async {
    uploadedDocumentTypes.add(documentType);
    return '$profileId/${applicationId ?? 'staging'}/$documentType-new.pdf';
  }

  @override
  Future<FranchiseDocument> replaceDocument({
    required String documentId,
    required String storagePath,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
  }) async {
    replacedDocumentIds.add(documentId);
    lastStoragePath = storagePath;
    return FranchiseDocument.fromMap({
      'id': documentId,
      'application_id': 'app-1',
      'document_type': 'or_cr',
      'verification_status': 'pending',
      'storage_path': storagePath,
      'file_name': fileName ?? 'file.pdf',
    });
  }

  @override
  Future<String?> signedDocumentUrl(
    String storagePath, {
    int expiresIn = 120,
  }) async {
    return signedUrlResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call to ${invocation.memberName}');
}

Widget _harness({
  required FranchiseApplication application,
  DocumentPicker? picker,
  DocumentService? service,
}) {
  return ProviderScope(
    overrides: [
      profileProvider.overrideWith((ref) => _profile),
      applicationDetailProvider.overrideWith((ref, id) => application),
      if (picker != null) documentPickerProvider.overrideWith((ref) => picker),
      if (service != null)
        documentServiceProvider.overrideWith((ref) => service),
    ],
    child:
        MaterialApp(home: ApplicationDocumentsScreen(application: application)),
  );
}

/// Pumps [widget] onto a surface tall enough that all four requirement cards
/// are laid out. The default 800x600 test window leaves the lower cards unbuilt,
/// and an unbuilt widget cannot be found.
Future<void> _pumpTall(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(520, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every requirement with its verification state',
      (tester) async {
    await _pumpTall(tester, _harness(application: _mixedPending()));

    for (final type in requiredDocumentTypes) {
      expect(find.text(documentLabels[type]!), findsOneWidget);
    }
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Verified'), findsNWidgets(2));
    expect(find.text('The OR/CR is blurred.'), findsOneWidget);

    expect(find.text('View'), findsNWidgets(4));
    // The pending and the rejected copy may be replaced; the two verified may not.
    expect(find.text('Replace'), findsNWidgets(2));
  });

  testWidgets('a verified copy offers no Replace and explains why',
      (tester) async {
    await _pumpTall(tester, _harness(application: _mixedPending()));

    final cedulaCard = find.ancestor(
      of: find.text(documentLabels['cedula']!),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: cedulaCard, matching: find.text('Replace')),
      findsNothing,
    );
    expect(
      find.text('Verified copies cannot be replaced.'),
      findsNWidgets(2),
    );
  });

  testWidgets('verified document card uses compact spacing and actions',
      (tester) async {
    await _pumpTall(tester, _harness(application: _mixedPending()));

    final label = find.text(documentLabels['cedula']!);
    final card = find.ancestor(of: label, matching: find.byType(Card));
    final viewButton = find.descendant(
        of: card, matching: find.widgetWithText(OutlinedButton, 'View'));

    expect(tester.widget<Text>(label).style?.fontSize, 13);
    expect(
      tester.getSize(viewButton).height,
      36,
    );
    expect(tester.getSize(card).height, lessThan(165));
    expect(
      find.descendant(
        of: card,
        matching: find.text('Verified copies cannot be replaced.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a decided application cannot replace documents', (tester) async {
    await _pumpTall(tester, _harness(application: _approvedAllVerified()));

    expect(find.text('Replace'), findsNothing);
    expect(
      find.textContaining('can only be replaced while it is under review'),
      findsOneWidget,
    );
    // The application-level notice covers it, so the per-document note is noise.
    expect(
      find.text('Verified copies cannot be replaced.'),
      findsNothing,
    );
  });

  testWidgets('a requirement with no file is shown as not on file',
      (tester) async {
    final application = _application(
      status: ApplicationStatus.pending,
      documents: [_doc('or_cr')],
    );
    await _pumpTall(tester, _harness(application: application));

    expect(find.text('Not on file'), findsNWidgets(3));
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('document card hides the uploaded filename', (tester) async {
    final application = _application(
      status: ApplicationStatus.pending,
      documents: [
        _doc(
          'member_association_certificate',
          verification: 'verified',
          fileName: 'Add a heading.png',
        ),
      ],
    );
    await _pumpTall(tester, _harness(application: application));

    expect(find.text('Add a heading.png'), findsNothing);
    expect(find.textContaining('Uploaded '), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('replacing a rejected copy uploads first, then calls the RPC',
      (tester) async {
    final service = _RecordingDocumentService();
    final picker = _FakePicker(
      PickedDocument(
        bytes: Uint8List(12),
        fileName: 'or-cr-new.pdf',
        mimeType: 'application/pdf',
      ),
    );

    await _pumpTall(
      tester,
      _harness(application: _mixedPending(), picker: picker, service: service),
    );

    final orCrCard = find.ancestor(
      of: find.text(documentLabels['or_cr']!),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: orCrCard, matching: find.text('Replace')),
    );
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(service.uploadedDocumentTypes, ['or_cr']);
    expect(service.replacedDocumentIds, ['doc-or_cr']);
    // The corrected file lands in the application's own folder.
    expect(service.lastStoragePath, 'profile-1/app-1/or_cr-new.pdf');
    expect(
      find.text('Document replaced. It will be reviewed again.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    final service = _RecordingDocumentService();
    final picker = _FakePicker(null);

    await _pumpTall(
      tester,
      _harness(application: _mixedPending(), picker: picker, service: service),
    );

    final orCrCard = find.ancestor(
      of: find.text(documentLabels['or_cr']!),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: orCrCard, matching: find.text('Replace')),
    );
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(service.uploadedDocumentTypes, isEmpty);
    expect(service.replacedDocumentIds, isEmpty);
  });

  testWidgets('viewing a PDF says preview needs the browser', (tester) async {
    await _pumpTall(
      tester,
      _harness(
        application: _mixedPending(),
        service: _RecordingDocumentService(),
      ),
    );

    final orCrCard = find.ancestor(
      of: find.text(documentLabels['or_cr']!),
      matching: find.byType(Card),
    );
    await tester
        .tap(find.descendant(of: orCrCard, matching: find.text('View')));
    await tester.pumpAndSettle();

    expect(find.textContaining('PDF preview is not available'), findsOneWidget);
  });

  testWidgets('viewing an image renders it inline', (tester) async {
    final application = _application(
      status: ApplicationStatus.pending,
      documents: [
        _doc('or_cr', mimeType: 'image/jpeg', fileName: 'or-cr.jpg'),
      ],
    );
    await _pumpTall(
      tester,
      _harness(
        application: application,
        service: _RecordingDocumentService(),
      ),
    );

    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).height, 220);
    expect(find.text('or-cr.jpg'), findsNothing);
    expect(find.textContaining('PDF preview is not available'), findsNothing);
  });

  testWidgets('the manager lists applications and opens their documents',
      (tester) async {
    final application = _mixedPending();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => _profile),
          myApplicationsStreamProvider
              .overrideWith((ref) => Stream.value([application])),
          applicationDetailProvider.overrideWith((ref, id) => application),
        ],
        child: const MaterialApp(home: DocumentManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My documents'), findsOneWidget);
    expect(find.text('SBTF-2026-0001'), findsOneWidget);

    await tester.tap(find.text('SBTF-2026-0001'));
    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsOneWidget);
    expect(find.text(documentLabels['or_cr']!), findsOneWidget);
  });
}
