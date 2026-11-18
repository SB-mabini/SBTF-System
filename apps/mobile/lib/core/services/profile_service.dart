import '../app_error.dart';
import 'service_base.dart';
import '../models/profile.dart';

/// Editing the signed-in operator's own profile.
///
/// The descriptive columns (name, contact, address, barangay) are the only ones
/// this service ever writes. The TODA, the role, the account status and the
/// membership roster entry are deliberately absent: they are set at
/// registration or by an administrator, and the app shows them read-only.
class ProfileService extends SupabaseService {
  ProfileService(super.client);

  Future<Profile?> refresh() {
    return guard(() async {
      final user = client.auth.currentUser;
      if (user == null) return null;
      final row = await client
          .from('profiles')
          .select('*, toda:todas(id, name, code), barangay:barangays(code, name)')
          .eq('auth_user_id', user.id)
          .maybeSingle();
      if (row == null) return null;
      return Profile.fromMap(Map<String, dynamic>.from(row));
    });
  }

  /// Saves the operator-editable fields of the caller's own profile.
  ///
  /// `toda_id`, `role` and `account_status` are not part of the payload: the UI
  /// never offers them, the migration `20261118000200` removes `toda_id` from the
  /// client update grant, and keeping them out of this method makes the
  /// guarantee explicit even if that grant ever changes.
  Future<void> updateMine({
    required String firstName,
    required String lastName,
    String? middleName,
    String? contactNumber,
    String? addressLine,
    String? barangayCode,
  }) {
    return guard(() async {
      ensureWritable();

      final user = client.auth.currentUser;
      if (user == null) {
        throw const AppFailure(
          kind: AppFailureKind.unauthorised,
          message: 'Your session is no longer valid. Please sign in again.',
          hint: 'Sign in again to continue.',
          recoverable: true,
        );
      }

      await client.from('profiles').update({
        'first_name': firstName.trim(),
        'middle_name': _blankToNull(middleName),
        'last_name': lastName.trim(),
        'contact_number': _blankToNull(contactNumber),
        'address_line': _blankToNull(addressLine),
        'barangay_code': _blankToNull(barangayCode),
      }).eq('auth_user_id', user.id);
    });
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
