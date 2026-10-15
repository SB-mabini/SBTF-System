import '../app_error.dart';
import '../models/application_event.dart';
import '../models/franchise_application.dart';
import 'service_base.dart';

/// Franchise applications — slice 3 (submission) and slice 4 (status tracking).
///
/// Writes go through `rpc_driver_submit_application`; reads are RLS-scoped
/// selects that can only ever return the caller's own rows.
class ApplicationService extends SupabaseService {
  ApplicationService(super.client);

  /// Columns selected for a list row: the application plus its TODA name.
  static const String _listSelect = '*, toda:todas(id, name, code)';

  /// Columns selected for a detail row: adds documents and the timeline.
  static const String _detailSelect = '*, toda:todas(id, name, code), '
      'documents:franchise_documents(*), timeline:application_status_history(*)';

  /// Submits a new or renewal application (slice 3).
  ///
  /// The four documents must already be uploaded to the caller's own storage
  /// folder (see `DocumentService`); the database re-checks that prefix and all
  /// business rules. [ApplicationSubmission.validate] is run first so an
  /// obviously invalid form never reaches the network.
  ///
  /// Throws an [AppFailure] on refusal — for a rule violation the message is
  /// the server's own sentence (for example "You already have a pending new
  /// franchise application").
  Future<FranchiseApplication> submit(ApplicationSubmission submission) {
    return guard(() async {
      ensureWritable();

      final problems = submission.validate();
      if (problems.isNotEmpty) {
        throw AppFailure(
          kind: AppFailureKind.businessRule,
          message: problems.first,
        );
      }

      final data = await client.rpc(
        'rpc_driver_submit_application',
        params: {'p_payload': submission.toPayload()},
      );
      return FranchiseApplication.fromMap(_asRow(data));
    });
  }

  /// The caller's own applications, newest first (slice 4).
  ///
  /// Pass [status] to narrow to `pending`, `approved` or `rejected`.
  Future<List<FranchiseApplication>> listMine({String? status}) {
    return guard(() async {
      var query = client.from('franchise_applications').select(_listSelect);
      if (status != null) query = query.eq('status', status);
      final rows = await query.order('submitted_at', ascending: false);
      return rows
          .map((row) => FranchiseApplication.fromMap(
              Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// The application the driver should open by default: the newest pending one,
  /// or the newest overall when nothing is pending.
  Future<FranchiseApplication?> activeApplication() {
    return guard(() async {
      final rows = await client
          .from('franchise_applications')
          .select(_listSelect)
          .order('submitted_at', ascending: false);
      final applications = rows
          .map((row) => FranchiseApplication.fromMap(
              Map<String, dynamic>.from(row as Map)))
          .toList();
      for (final application in applications) {
        if (application.isPending) return application;
      }
      return applications.isEmpty ? null : applications.first;
    });
  }

  /// One application with its documents and timeline, or null when it does not
  /// exist / is not the caller's.
  Future<FranchiseApplication?> getById(String id) {
    return guard(() async {
      final row = await client
          .from('franchise_applications')
          .select(_detailSelect)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return FranchiseApplication.fromMap(Map<String, dynamic>.from(row));
    });
  }

  /// Just the timeline of one application, oldest first.
  Future<List<ApplicationEvent>> listTimeline(String applicationId) {
    return guard(() async {
      final rows = await client
          .from('application_status_history')
          .select()
          .eq('application_id', applicationId)
          .order('created_at');
      return rows
          .map((row) =>
              ApplicationEvent.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// Live list of the caller's applications (slice 4). RLS limits the stream to
  /// the caller's own rows; a status change reaches the app without a refresh.
  Stream<List<FranchiseApplication>> watchMine() {
    return client
        .from('franchise_applications')
        .stream(primaryKey: ['id'])
        .order('submitted_at')
        .map((rows) => rows.map(FranchiseApplication.fromMap).toList());
  }

  /// Live single-application updates, filtered by id.
  Stream<FranchiseApplication?> watchById(String id) {
    return client
        .from('franchise_applications')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) =>
            rows.isEmpty ? null : FranchiseApplication.fromMap(rows.first));
  }

  /// PostgREST returns a composite-returning RPC as a single JSON object, but a
  /// set-returning one as an array; accept either shape.
  static Map<String, dynamic> _asRow(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    throw StateError('The server did not return the submitted application.');
  }
}
