import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sbtf_mobile/core/models/certificate_verification.dart';
import 'package:sbtf_mobile/core/models/franchise_record.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/core/qr_scanner.dart';
import 'package:sbtf_mobile/core/services/certificate_service.dart';
import 'package:sbtf_mobile/core/url_opener.dart';
import 'package:sbtf_mobile/features/certificate/certificate_detail_screen.dart';
import 'package:sbtf_mobile/features/certificate/certificate_list_screen.dart';
import 'package:sbtf_mobile/features/certificate/certificate_verify_screen.dart';

const String _baseUrl = 'https://mabini.gov.ph/verify';
const String _scannedPayload = 'https://mabini.gov.ph/verify?code=ABCDEFGHJKLM';

FranchiseRecord _record({
  required String id,
  String franchiseNumber = 'SBTF-2026-0001',
  String verificationCode = 'ABCDEFGHJKLM',
  DateTime? issuedAt,
  DateTime? expiresAt,
  bool archived = false,
  String? certificateStoragePath,
}) {
  return FranchiseRecord(
    id: id,
    applicationId: 'app-$id',
    operatorId: 'op-1',
    todaId: 'toda-1',
    franchiseNumber: franchiseNumber,
    verificationCode: verificationCode,
    issuedAt: issuedAt ?? DateTime(2026, 1, 1),
    // Far enough out that the record reads as active regardless of the clock.
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 400)),
    archived: archived,
    certificateStoragePath: certificateStoragePath,
    todaName: 'Mabini TODA',
    plateNumber: 'ABC 1234',
    vehicleMake: 'Honda',
    vehicleModel: 'Wave',
    vehicleYear: 2020,
    operatorName: 'Juan Dela Cruz',
  );
}

CertificateVerification _validVerification() {
  return CertificateVerification(
    verificationStatus: 'valid',
    franchiseNumber: 'SBTF-2026-0001',
    operatorDisplayName: 'J*** D*** C***',
    todaName: 'Mabini TODA',
    issuedAt: DateTime(2026, 1, 1),
    expiresAt: DateTime(2027, 1, 1),
    verifiedAt: DateTime(2026, 9, 1),
  );
}

/// A stand-in for [CertificateService].
///
/// It deliberately does *not* extend the real service: constructing that builds
/// a `SupabaseClient`, whose background auth-refresh timer a widget test reports
/// as a leak. Only the members the screens touch are implemented; anything else
/// fails loudly through [noSuchMethod], so an unexpected call is caught.
class _FakeCertificateService implements CertificateService {
  _FakeCertificateService({
    this.records = const [],
    CertificateVerification? verification,
    this.baseUrl = _baseUrl,
  }) : verification = verification ?? CertificateVerification.notFound();

  static const String _signedUrl =
      'https://example.supabase.co/storage/v1/object/sign/certificates/cert.pdf';

  final List<FranchiseRecord> records;
  final CertificateVerification verification;
  final String? baseUrl;

  final List<String> verifiedValues = <String>[];
  int signedUrlCalls = 0;

  @override
  Future<List<FranchiseRecord>> listMine() async => records;

  @override
  Stream<List<FranchiseRecord>> watchMine() => Stream.value(records);

  @override
  Future<String?> verificationBaseUrl() async => baseUrl;

  @override
  Future<String?> certificateSignedUrl(
    FranchiseRecord record, {
    int expiresIn = 300,
  }) async {
    signedUrlCalls++;
    return record.hasCertificate ? _signedUrl : null;
  }

  @override
  Future<CertificateVerification> verify(String scannedValue) async {
    verifiedValues.add(scannedValue);
    return verification;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call to ${invocation.memberName}');
}

/// A scanner view with no camera: tapping the button reports a fixed code, the
/// way a real preview would.
Widget _fakeScanner(BuildContext context, QrScanCallback onDetect) {
  return Center(
    child: ElevatedButton(
      onPressed: () => onDetect(_scannedPayload),
      child: const Text('Simulate scan'),
    ),
  );
}

Widget _harness({
  required Widget home,
  CertificateService? service,
  UrlLauncher? launcher,
  QrScannerViewBuilder? scanner,
}) {
  return ProviderScope(
    overrides: [
      if (service != null)
        certificateServiceProvider.overrideWith((ref) => service),
      if (launcher != null) urlLauncherProvider.overrideWith((ref) => launcher),
      if (scanner != null)
        qrScannerViewBuilderProvider.overrideWith((ref) => scanner),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// Pumps onto a surface tall enough that the detail screen's lower cards are
/// laid out; the default 800x600 window leaves them unbuilt.
Future<void> _pumpTall(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(520, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  group('certificate list', () {
    testWidgets('lists each certificate with its state', (tester) async {
      final service = _FakeCertificateService(
        records: [
          _record(id: 'r1', franchiseNumber: 'SBTF-2026-0001'),
          _record(
            id: 'r2',
            franchiseNumber: 'SBTF-2026-0002',
            expiresAt: DateTime.now().add(const Duration(days: 30)),
          ),
          _record(
            id: 'r3',
            franchiseNumber: 'SBTF-2026-0003',
            expiresAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          _record(id: 'r4', franchiseNumber: 'SBTF-2026-0004', archived: true),
        ],
      );

      await _pump(
        tester,
        _harness(home: const CertificateListScreen(), service: service),
      );

      expect(find.text('SBTF-2026-0001'), findsOneWidget);
      expect(find.text('SBTF-2026-0004'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Expiring soon'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('an empty list explains when a certificate appears',
        (tester) async {
      await _pump(
        tester,
        _harness(
          home: const CertificateListScreen(),
          service: _FakeCertificateService(),
        ),
      );

      expect(find.text('No franchise certificate yet'), findsOneWidget);
      expect(find.text('Verify a certificate'), findsOneWidget);
    });

    testWidgets('a row opens its certificate detail', (tester) async {
      final record = _record(id: 'r1');
      await _pump(
        tester,
        _harness(
          home: const CertificateListScreen(),
          service: _FakeCertificateService(records: [record]),
        ),
      );

      await tester.tap(find.text('SBTF-2026-0001'));
      await tester.pumpAndSettle();

      expect(find.text('Franchise certificate'), findsOneWidget);
    });
  });

  group('certificate detail', () {
    testWidgets('shows the verification code and the QR image', (tester) async {
      final record = _record(id: 'r1');
      await _pumpTall(
        tester,
        _harness(
          home: CertificateDetailScreen(record: record),
          service: _FakeCertificateService(records: [record]),
        ),
      );

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('ABCDEFGHJKLM'), findsWidgets);
      expect(find.text('SBTF-2026-0001'), findsWidgets);
    });

    testWidgets('opens the certificate through a signed URL', (tester) async {
      final record = _record(
        id: 'r1',
        certificateStoragePath: 'op-1/SBTF-2026-0001.pdf',
      );
      final service = _FakeCertificateService(records: [record]);
      Uri? launched;

      await _pumpTall(
        tester,
        _harness(
          home: CertificateDetailScreen(record: record),
          service: service,
          launcher: (url) async {
            launched = url;
            return true;
          },
        ),
      );

      await tester.tap(find.text('Open certificate'));
      await tester.pumpAndSettle();

      expect(service.signedUrlCalls, 1);
      expect(launched, isNotNull);
      expect(launched.toString(), contains('/certificates/cert.pdf'));
    });

    testWidgets('a record without a file cannot be opened', (tester) async {
      final record = _record(id: 'r1');
      final service = _FakeCertificateService(records: [record]);

      await _pumpTall(
        tester,
        _harness(
          home: CertificateDetailScreen(record: record),
          service: service,
        ),
      );

      expect(
        find.textContaining('certificate file is not available yet'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Open certificate'),
      );
      expect(button.onPressed, isNull);
      expect(service.signedUrlCalls, 0);
    });

    testWidgets('copying the link writes the verification URL', (tester) async {
      final record = _record(id: 'r1');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _pumpTall(
        tester,
        _harness(
          home: CertificateDetailScreen(record: record),
          service: _FakeCertificateService(records: [record]),
        ),
      );

      await tester.tap(find.text('Copy verification link'));
      await tester.pumpAndSettle();

      expect(copied, '$_baseUrl?code=ABCDEFGHJKLM');
    });

    testWidgets('without a base URL the link carries the bare code',
        (tester) async {
      final record = _record(id: 'r1');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _pumpTall(
        tester,
        _harness(
          home: CertificateDetailScreen(record: record),
          service: _FakeCertificateService(records: [record], baseUrl: null),
        ),
      );

      await tester.tap(find.text('Copy verification link'));
      await tester.pumpAndSettle();

      // The scanner resolves a bare code the same way, so the QR stays useful.
      expect(copied, 'ABCDEFGHJKLM');
    });
  });

  group('certificate verification', () {
    testWidgets('a scanned code resolves through the verifier', (tester) async {
      final service = _FakeCertificateService(
        verification: _validVerification(),
      );

      await _pump(
        tester,
        _harness(
          home: const CertificateVerifyScreen(),
          service: service,
          scanner: _fakeScanner,
        ),
      );

      await tester.tap(find.text('Simulate scan'));
      await tester.pumpAndSettle();

      expect(service.verifiedValues, [_scannedPayload]);
      expect(find.text('Valid franchise'), findsOneWidget);
      expect(find.text('J*** D*** C***'), findsOneWidget);
      expect(find.text('SBTF-2026-0001'), findsOneWidget);
    });

    testWidgets('a typed code is verified the same way', (tester) async {
      final service = _FakeCertificateService(
        verification: _validVerification(),
      );

      await _pump(
        tester,
        _harness(
          home: const CertificateVerifyScreen(),
          service: service,
          scanner: _fakeScanner,
        ),
      );

      await tester.enterText(find.byType(TextField), 'abcd efgh jklm');
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();

      // The screen forwards the raw input; the service normalises it.
      expect(service.verifiedValues, ['abcd efgh jklm']);
      expect(find.text('Valid franchise'), findsOneWidget);
    });

    testWidgets('an unknown code is reported as not found', (tester) async {
      final service = _FakeCertificateService();

      await _pump(
        tester,
        _harness(
          home: const CertificateVerifyScreen(),
          service: service,
          scanner: _fakeScanner,
        ),
      );

      await tester.enterText(find.byType(TextField), 'ZZZZZZZZZZZZ');
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();

      expect(find.text('Certificate not found'), findsWidgets);
      expect(
        find.textContaining('No franchise matches this code'),
        findsOneWidget,
      );
    });

    testWidgets('an empty submission is ignored', (tester) async {
      final service = _FakeCertificateService(
        verification: _validVerification(),
      );

      await _pump(
        tester,
        _harness(
          home: const CertificateVerifyScreen(),
          service: service,
          scanner: _fakeScanner,
        ),
      );

      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();

      expect(service.verifiedValues, isEmpty);
      expect(find.text('Valid franchise'), findsNothing);
    });
  });
}
