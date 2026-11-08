import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_error.dart';
import '../constants.dart';
import '../models/form_request.dart';
import 'service_base.dart';

/// Request-form-first workflow — driver side.
///
/// A driver files a complete vehicle/franchise request (letter data, one
/// combined OR/CR file and a signature) before an application exists. Staff
/// approve it, and `rpc_driver_submit_application` then copies its vehicle
/// identity and OR/CR into the application and consumes the request.
class FormRequestService extends SupabaseService {
  FormRequestService(super.client);

  static const String _select = '*';

  /// The caller's own requests, newest first.
  Future<List<FormRequest>> listMine() {
    return guard(() async {
      final rows = await client
          .from('form_requests')
          .select(_select)
          .order('created_at', ascending: false);
      return rows
          .map((row) =>
              FormRequest.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// One of the caller's own requests by id (RLS limits it to the caller).
  Future<FormRequest?> getById(String id) {
    return guard(() async {
      final row = await client
          .from('form_requests')
          .select(_select)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return FormRequest.fromMap(Map<String, dynamic>.from(row));
    });
  }

  /// The request occupying the driver's open slot (`requested` or `issued`),
  /// if any.
  Future<FormRequest?> openRequest() {
    return guard(() async {
      final rows = await client
          .from('form_requests')
          .select(_select)
          .inFilter('status', ['requested', 'issued'])
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return FormRequest.fromMap(Map<String, dynamic>.from(rows.first as Map));
    });
  }

  /// The newest rejected request, which the driver can edit and resubmit.
  Future<FormRequest?> latestRejected() {
    return guard(() async {
      final rows = await client
          .from('form_requests')
          .select(_select)
          .eq('status', FormRequestStatus.rejected)
          .order('updated_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return FormRequest.fromMap(Map<String, dynamic>.from(rows.first as Map));
    });
  }

  /// Files a new request.
  Future<FormRequest> request(FormRequestSubmission submission) {
    return guard(() async {
      ensureWritable();
      _validate(submission);

      final data = await client.rpc(
        'rpc_driver_request_form',
        params: {'p_payload': submission.toPayload()},
      );
      return FormRequest.fromMap(_asRow(data));
    });
  }

  /// Edits and resubmits a rejected request on the same row.
  Future<FormRequest> updateRejected(
    String id,
    FormRequestSubmission submission,
  ) {
    return guard(() async {
      ensureWritable();
      _validate(submission);

      final data = await client.rpc(
        'rpc_driver_update_form_request',
        params: {
          'p_form_request_id': id,
          'p_payload': submission.toPayload(),
        },
      );
      return FormRequest.fromMap(_asRow(data));
    });
  }

  /// Cancels an open request.
  Future<FormRequest> cancel(String id, {String? reason}) {
    return guard(() async {
      ensureWritable();
      final data = await client.rpc(
        'rpc_driver_cancel_form_request',
        params: {
          'p_form_request_id': id,
          'p_reason': reason,
        },
      );
      return FormRequest.fromMap(_asRow(data));
    });
  }

  /// Uploads the single combined OR/CR file (front and back) to the caller's
  /// own folder and returns its storage path.
  Future<String> uploadOrCr({
    required String profileId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String folder = 'form-requests',
    int? epochMillis,
  }) {
    return guard(() async {
      ensureWritable();
      _checkFile(bytes.length, mimeType);

      final epoch = epochMillis ?? DateTime.now().millisecondsSinceEpoch;
      final extension = _extensionOf(fileName);
      final suffix = extension.isEmpty ? '' : '.$extension';
      final path = '$profileId/$folder/or-cr-$epoch$suffix';

      await client.storage.from(StorageBuckets.documents).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );
      return path;
    });
  }

  /// Uploads the drawn signature PNG and returns its storage path.
  Future<String> uploadSignature({
    required String profileId,
    required Uint8List bytes,
    String folder = 'form-requests',
    int? epochMillis,
  }) {
    return guard(() async {
      ensureWritable();
      if (bytes.isEmpty || bytes.length > maxUploadBytes) {
        throw const AppFailure(
          kind: AppFailureKind.businessRule,
          message: 'The signature image is empty or too large.',
        );
      }

      final epoch = epochMillis ?? DateTime.now().millisecondsSinceEpoch;
      final path = '$profileId/$folder/signature-$epoch.png';
      await client.storage.from(StorageBuckets.documents).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/png'),
          );
      return path;
    });
  }

  /// Live status changes for the driver's requests (staff approval/rejection).
  Stream<List<FormRequest>> watchMine() {
    return client
        .from('form_requests')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(FormRequest.fromMap).toList());
  }

  static void _validate(FormRequestSubmission submission) {
    final problems = submission.validate();
    if (problems.isNotEmpty) {
      throw AppFailure(
        kind: AppFailureKind.businessRule,
        message: problems.first,
      );
    }
  }

  static void _checkFile(int sizeBytes, String? mimeType) {
    if (mimeType != null && !acceptedUploadMimeTypes.contains(mimeType)) {
      throw const AppFailure(
        kind: AppFailureKind.businessRule,
        message: 'The OR/CR must be a PDF, JPEG or PNG file.',
      );
    }
    if (sizeBytes > maxUploadBytes) {
      throw const AppFailure(
        kind: AppFailureKind.businessRule,
        message: 'The OR/CR must not exceed 10 MB.',
      );
    }
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    final extension = fileName.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension) ? extension : '';
  }

  static Map<String, dynamic> _asRow(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    throw StateError('The server did not return the form request.');
  }
}
