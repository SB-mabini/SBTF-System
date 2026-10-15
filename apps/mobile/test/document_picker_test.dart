import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/constants.dart';
import 'package:sbtf_mobile/core/document_picker.dart';

void main() {
  group('resolveMimeType', () {
    test('keeps a provided type the server accepts', () {
      expect(resolveMimeType('scan.bin', 'image/png'), 'image/png');
    });

    test('infers from the extension when the platform gives nothing', () {
      expect(resolveMimeType('receipt.PDF', null), 'application/pdf');
      expect(resolveMimeType('photo.jpeg', null), 'image/jpeg');
      expect(resolveMimeType('photo.jpg', null), 'image/jpeg');
      expect(resolveMimeType('cedula.png', null), 'image/png');
    });

    test('overrides a rejected provided type when the extension is known', () {
      expect(
        resolveMimeType('scan.pdf', 'application/octet-stream'),
        'application/pdf',
      );
    });

    test('falls back to the provided type when the extension is unknown', () {
      expect(
        resolveMimeType('document', 'application/msword'),
        'application/msword',
      );
    });

    test('falls back to octet-stream when nothing is known', () {
      expect(resolveMimeType('document', null), 'application/octet-stream');
      expect(resolveMimeType('.hidden', null), 'application/octet-stream');
      expect(resolveMimeType('trailing.', null), 'application/octet-stream');
    });
  });

  group('PickedDocument', () {
    PickedDocument doc({required String mimeType, required int length}) =>
        PickedDocument(
          bytes: Uint8List(length),
          fileName: 'file',
          mimeType: mimeType,
        );

    test('accepts the three server formats and rejects others', () {
      expect(
          doc(mimeType: 'application/pdf', length: 1).isAcceptedType, isTrue);
      expect(doc(mimeType: 'image/jpeg', length: 1).isAcceptedType, isTrue);
      expect(doc(mimeType: 'image/png', length: 1).isAcceptedType, isTrue);
      expect(
        doc(mimeType: 'application/zip', length: 1).isAcceptedType,
        isFalse,
      );
    });

    test('checks the 10 MB limit inclusively', () {
      expect(
        doc(mimeType: 'application/pdf', length: maxUploadBytes)
            .isWithinSizeLimit,
        isTrue,
      );
      expect(
        doc(mimeType: 'application/pdf', length: maxUploadBytes + 1)
            .isWithinSizeLimit,
        isFalse,
      );
    });
  });
}
