import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'constants.dart';

/// A documentary requirement the driver picked from their device, ready to
/// upload to the private `franchise-documents` bucket.
///
/// The bytes are held in memory between choosing the file and uploading it.
/// Every requirement is at most [maxUploadBytes] (10 MB), enforced by the
/// storage policy and re-checked server-side, so buffering one file at a time
/// is safe on a phone.
class PickedDocument {
  PickedDocument({
    required Uint8List bytes,
    required this.fileName,
    required this.mimeType,
  })  : bytes = bytes,
        sizeBytes = bytes.length;

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// True when the server would accept the MIME type.
  bool get isAcceptedType => acceptedUploadMimeTypes.contains(mimeType);

  /// True when the file is within the 10 MB limit.
  bool get isWithinSizeLimit => sizeBytes <= maxUploadBytes;
}

/// Chooses one file from the device.
///
/// Kept behind an interface so the wizard never imports a platform plugin
/// directly: a screen asks the provider for a [DocumentPicker], which makes the
/// form testable (inject a fake) and keeps preview mode off the plugin channel.
abstract class DocumentPicker {
  /// Returns the chosen file, or null when the user cancelled.
  Future<PickedDocument?> pick();
}

/// The real picker, backed by the platform file chooser (`file_selector`).
class FileSelectorDocumentPicker implements DocumentPicker {
  const FileSelectorDocumentPicker();

  /// Android requires non-empty `extensions` or `mimeTypes` per group; both are
  /// supplied so the chooser filters to the three server-accepted formats on
  /// every platform.
  static const XTypeGroup _documents = XTypeGroup(
    label: 'Document (PDF or image)',
    extensions: ['pdf', 'jpg', 'jpeg', 'png'],
    mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
  );

  @override
  Future<PickedDocument?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_documents]);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return PickedDocument(
      bytes: bytes,
      fileName: file.name,
      mimeType: resolveMimeType(file.name, file.mimeType),
    );
  }
}

/// Resolves the MIME type to send to the server.
///
/// Prefers [provided] (the platform's own guess) when it is one we accept;
/// otherwise infers from the file extension. Returns the provided value or
/// `application/octet-stream` when neither is conclusive, so the caller rejects
/// it with the same message the server would use rather than guessing wrong.
String resolveMimeType(String fileName, String? provided) {
  if (provided != null && acceptedUploadMimeTypes.contains(provided)) {
    return provided;
  }

  final dot = fileName.lastIndexOf('.');
  if (dot > 0 && dot < fileName.length - 1) {
    switch (fileName.substring(dot + 1).toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
    }
  }

  return provided ?? 'application/octet-stream';
}
