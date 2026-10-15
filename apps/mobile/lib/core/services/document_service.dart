import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_error.dart';
import '../constants.dart';
import '../models/franchise_document.dart';
import 'service_base.dart';

/// Document upload and replacement — slice 5.
///
/// Files are uploaded directly to the private `franchise-documents` bucket, to
/// the caller's own folder only (the storage policy and both driver RPCs
/// re-check that the path starts with the caller's profile id). The database
/// row is attached by `rpc_driver_submit_application`; a rejected or pending
/// copy is corrected through `rpc_driver_replace_document`.
class DocumentService extends SupabaseService {
  DocumentService(super.client);

  /// Folder used before an application exists, so the file is in place when
  /// `rpc_driver_submit_application` runs.
  static const String stagingFolder = 'staging';

  /// Builds the storage path for a document.
  ///
  /// Shape matches the convention in `20260101091000_phase0_storage.sql`:
  /// `{profileId}/{applicationId|staging}/{documentType}-{epoch}.{ext}`.
  /// Segment 1 is always the owning profile id — the only thing the storage
  /// policies inspect.
  static String buildStoragePath({
    required String profileId,
    required String documentType,
    required String fileName,
    String? applicationId,
    int? epochMillis,
  }) {
    final folder = (applicationId == null || applicationId.isEmpty)
        ? stagingFolder
        : applicationId;
    final epoch = epochMillis ?? DateTime.now().millisecondsSinceEpoch;
    final extension = _extensionOf(fileName);
    final suffix = extension.isEmpty ? '' : '.$extension';
    return '$profileId/$folder/$documentType-$epoch$suffix';
  }

  /// Uploads one documentary requirement before submission.
  ///
  /// Returns the stored path to hand to [ApplicationDocumentUpload]. The MIME
  /// type and size are validated here so the user is told before the upload
  /// rather than after the RPC refuses the whole application.
  Future<String> uploadDocument({
    required String profileId,
    required String documentType,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? applicationId,
    int? epochMillis,
  }) {
    return guard(() async {
      ensureWritable();
      _checkFile(bytes.length, mimeType);

      final path = buildStoragePath(
        profileId: profileId,
        documentType: documentType,
        fileName: fileName,
        applicationId: applicationId,
        epochMillis: epochMillis,
      );

      await client.storage.from(StorageBuckets.documents).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );
      return path;
    });
  }

  /// Replaces a document on the caller's own pending application — typically a
  /// copy staff rejected (slice 5).
  ///
  /// Upload the corrected file first (with [uploadDocument]) and pass the
  /// returned path here. The RPC resets verification to `pending`; the trigger
  /// writes the audit trail and timeline.
  Future<FranchiseDocument> replaceDocument({
    required String documentId,
    required String storagePath,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
  }) {
    return guard(() async {
      ensureWritable();
      if (mimeType != null || fileSizeBytes != null) {
        _checkFile(fileSizeBytes ?? 0, mimeType);
      }

      final data = await client.rpc(
        'rpc_driver_replace_document',
        params: {
          'p_document_id': documentId,
          'p_storage_path': storagePath,
          'p_file_name': fileName,
          'p_file_size_bytes': fileSizeBytes,
          'p_mime_type': mimeType,
        },
      );
      return FranchiseDocument.fromMap(_asRow(data));
    });
  }

  /// A short-lived signed URL for viewing a stored document. Returns null when
  /// the current session may not read it (RLS refuses the request).
  Future<String?> signedDocumentUrl(String storagePath, {int expiresIn = 120}) {
    return guard(() async {
      if (storagePath.isEmpty) return null;
      try {
        return await client.storage
            .from(StorageBuckets.documents)
            .createSignedUrl(storagePath, expiresIn);
      } catch (_) {
        return null;
      }
    });
  }

  /// Deletes a file the driver uploaded but never linked to an application.
  ///
  /// The storage delete policy permits owners to remove files in their own
  /// folder; linked files are removed by deleting the application, not by this
  /// call. Best-effort: failures are ignored so cleanup never blocks the UI.
  Future<void> removeUpload(String storagePath) {
    return guard(() async {
      ensureWritable();
      if (storagePath.isEmpty) return;
      try {
        await client.storage
            .from(StorageBuckets.documents)
            .remove([storagePath]);
      } catch (_) {
        // Cleanup is best-effort.
      }
    });
  }

  static void _checkFile(int sizeBytes, String? mimeType) {
    if (mimeType != null && !acceptedUploadMimeTypes.contains(mimeType)) {
      throw const AppFailure(
        kind: AppFailureKind.businessRule,
        message: 'Documents must be PDF, JPEG or PNG files.',
      );
    }
    if (sizeBytes > maxUploadBytes) {
      throw const AppFailure(
        kind: AppFailureKind.businessRule,
        message: 'Each document must not exceed 10 MB.',
      );
    }
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    final extension = fileName.substring(dot + 1).toLowerCase();
    // Keep only a simple, safe extension; anything else is dropped.
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension) ? extension : '';
  }

  static Map<String, dynamic> _asRow(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    throw StateError('The server did not return the replaced document.');
  }
}
