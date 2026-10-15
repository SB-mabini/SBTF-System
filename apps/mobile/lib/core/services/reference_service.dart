import '../models/toda.dart';
import 'service_base.dart';

/// Reference data the application form needs (slice 3 support).
///
/// TODAs and barangays are readable by anyone by policy
/// (`20260101090900_phase0_rls_policies.sql`), so these reads need no special
/// privileges — they simply populate the pickers.
class ReferenceService extends SupabaseService {
  ReferenceService(super.client);

  /// The accredited, active TODAs an application may be filed under.
  ///
  /// Inactive TODAs are hidden because `rpc_driver_submit_application` refuses
  /// them server-side ("The selected TODA is not accredited or is inactive").
  Future<List<Toda>> listTodas({bool activeOnly = true}) {
    return guard(() async {
      var query = client.from('todas').select('id, code, name, barangay_code, '
          'zone, members_count, is_active');
      if (activeOnly) query = query.eq('is_active', true);
      final rows = await query.order('name');
      return rows
          .map((row) => Toda.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// Every barangay of Mabini, in official sort order.
  Future<List<Barangay>> listBarangays() {
    return guard(() async {
      final rows = await client
          .from('barangays')
          .select('code, name')
          .order('sort_order');
      return rows
          .map((row) => Barangay.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }

  /// Looks a TODA up by id within an already-loaded list; small convenience for
  /// forms that hold the list and a selected id.
  static Toda? findToda(List<Toda> todas, String? id) {
    if (id == null) return null;
    for (final toda in todas) {
      if (toda.id == id) return toda;
    }
    return null;
  }
}
