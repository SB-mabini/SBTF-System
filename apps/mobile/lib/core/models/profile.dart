/// Application-level profile, mirroring the `public.profiles` table.
///
/// The web console and the mobile app share this schema. The model keeps the
/// fields the mobile slices actually use and parses defensively: Supabase
/// returns rows as `Map<String, dynamic>`, and a column being absent or null
/// must not crash the app.
class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.authUserId,
    this.middleName,
    this.computedFullName,
    this.contactNumber,
    this.addressLine,
    this.barangayCode,
    this.todaId,
    this.todaName,
    this.todaCode,
    this.barangayName,
    this.createdAt,
    this.accountStatus = 'active',
  });

  final String id;
  final String? authUserId;
  final String role;
  final String firstName;
  final String? middleName;
  final String lastName;

  /// The `full_name` column is a GENERATED column in PostgreSQL. It is present
  /// on live databases, but a row built elsewhere may not carry it — hence the
  /// fallback in [fullName].
  final String? computedFullName;

  final String email;
  final String? contactNumber;
  final String? addressLine;
  final String? barangayCode;

  /// The TODA the operator belongs to. View-only in the app: the association
  /// is fixed when the operator registers and is never edited from a profile
  /// form.
  final String? todaId;
  final String? todaName;
  final String? todaCode;

  /// Joined barangay name, present when the query embeds `barangays`.
  final String? barangayName;
  final DateTime? createdAt;
  final String accountStatus;

  /// Display name. Uses the generated `full_name` column when available and
  /// falls back to assembling first + middle + last when it is absent, so the
  /// app still renders a sensible name against a partially-provisioned row.
  String get fullName {
    final computed = computedFullName;
    if (computed != null && computed.trim().isNotEmpty) {
      return computed.trim();
    }
    final parts = <String>[
      firstName,
      if (middleName != null && middleName!.trim().isNotEmpty) middleName!,
      lastName,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? email : parts.join(' ');
  }

  bool get isDriver => role == 'driver';

  bool get isActive => accountStatus == 'active';

  bool get isSuspended => accountStatus == 'suspended';

  /// Initials for the avatar, derived from the display name: the first
  /// letters of the first two tokens. This mirrors the web console's
  /// `initials()` (apps/web/src/lib/format.ts), so "Juan Dela Cruz" renders
  /// "JD" in both clients — important for multi-word Filipino surnames,
  /// where first + last token would wrongly yield "JC".
  String get initials {
    final tokens = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '?';
    if (tokens.length == 1) return _firstChar(tokens.first).toUpperCase();
    return (_firstChar(tokens.first) + _firstChar(tokens[1])).toUpperCase();
  }

  static String _firstChar(String value) => value.isEmpty ? '' : value[0];

  factory Profile.fromMap(Map<String, dynamic> map) {
    final toda = map['toda'] ?? map['todas'];
    final barangay = map['barangay'] ?? map['barangays'];

    return Profile(
      id: (map['id'] ?? '').toString(),
      authUserId: map['auth_user_id']?.toString(),
      role: (map['role'] ?? 'driver').toString(),
      firstName: (map['first_name'] ?? '').toString(),
      middleName: map['middle_name']?.toString(),
      lastName: (map['last_name'] ?? '').toString(),
      computedFullName: map['full_name']?.toString(),
      email: (map['email'] ?? '').toString(),
      contactNumber: map['contact_number']?.toString(),
      addressLine: map['address_line']?.toString(),
      barangayCode: map['barangay_code']?.toString(),
      todaId: map['toda_id']?.toString(),
      todaName: toda is Map ? toda['name']?.toString() : null,
      todaCode: toda is Map ? toda['code']?.toString() : null,
      barangayName: barangay is Map ? barangay['name']?.toString() : null,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      accountStatus: (map['account_status'] ?? 'active').toString(),
    );
  }
}
