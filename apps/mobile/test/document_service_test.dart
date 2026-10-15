import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/services/document_service.dart';

void main() {
  group('DocumentService.buildStoragePath', () {
    test('uses the staging folder when no application exists yet', () {
      expect(
        DocumentService.buildStoragePath(
          profileId: 'profile-1',
          documentType: 'or_cr',
          fileName: 'receipt.pdf',
          epochMillis: 1700000000000,
        ),
        'profile-1/staging/or_cr-1700000000000.pdf',
      );
    });

    test('uses the staging folder for a blank application id', () {
      expect(
        DocumentService.buildStoragePath(
          profileId: 'profile-1',
          documentType: 'cedula',
          fileName: 'cedula.png',
          applicationId: '',
          epochMillis: 1700000000000,
        ),
        'profile-1/staging/cedula-1700000000000.png',
      );
    });

    test('uses the application folder when one is provided', () {
      expect(
        DocumentService.buildStoragePath(
          profileId: 'profile-1',
          documentType: 'barangay_clearance',
          fileName: 'clearance.pdf',
          applicationId: 'app-9',
          epochMillis: 1700000000000,
        ),
        'profile-1/app-9/barangay_clearance-1700000000000.pdf',
      );
    });

    test('lower-cases a known extension', () {
      expect(
        DocumentService.buildStoragePath(
          profileId: 'profile-1',
          documentType: 'or_cr',
          fileName: 'SCAN.JPEG',
          epochMillis: 1700000000000,
        ),
        'profile-1/staging/or_cr-1700000000000.jpeg',
      );
    });

    test('drops a missing, hidden or oversized extension', () {
      String pathOf(String fileName) => DocumentService.buildStoragePath(
            profileId: 'p',
            documentType: 'or_cr',
            fileName: fileName,
            epochMillis: 1,
          );

      expect(pathOf('noextension'), 'p/staging/or_cr-1');
      expect(pathOf('.hidden'), 'p/staging/or_cr-1');
      expect(pathOf('trailing.'), 'p/staging/or_cr-1');
      expect(pathOf('scan.toolongext'), 'p/staging/or_cr-1');
      expect(pathOf('scan.p!d'), 'p/staging/or_cr-1');
    });

    test('falls back to the current time for the epoch segment', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final path = DocumentService.buildStoragePath(
        profileId: 'profile-1',
        documentType: 'or_cr',
        fileName: 'receipt.pdf',
      );
      final after = DateTime.now().millisecondsSinceEpoch;

      final epoch =
          int.parse(RegExp(r'-(\d+)\.pdf$').firstMatch(path)!.group(1)!);
      expect(epoch, inInclusiveRange(before, after));
    });
  });
}
