import '../models/announcement.dart';
import 'service_base.dart';

/// Published announcements addressed to the signed-in driver.
///
/// The `announcements` table is read-only for drivers: RLS returns only
/// published rows whose audience resolves to the caller, and the full body
/// lives on the row rather than in the notification copy.
class AnnouncementService extends SupabaseService {
  AnnouncementService(super.client);

  static const String _select =
      '*, author:profiles!announcements_created_by_fkey(full_name)';

  /// Published announcements, newest first.
  Future<List<Announcement>> listPublished({int limit = 50}) {
    return guard(() async {
      final rows = await client
          .from('announcements')
          .select(_select)
          .eq('status', 'published')
          .order('published_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) =>
              Announcement.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// One published announcement by id, or null when it is not addressed to the
  /// caller (RLS makes an unknown id indistinguishable from a missing one).
  Future<Announcement?> getById(String id) {
    return guard(() async {
      final row = await client
          .from('announcements')
          .select(_select)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return Announcement.fromMap(Map<String, dynamic>.from(row));
    });
  }

  /// Live published announcements, so a newly published notice appears without
  /// a manual refresh.
  Stream<List<Announcement>> watchPublished() {
    return client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('status', 'published')
        .order('published_at')
        .map((rows) => rows
            .map((row) => Announcement.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }
}
