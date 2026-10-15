/// A TODA (Tricycle Operators and Drivers Association) as exposed by the
/// `public.todas` table. Reference data: readable by anyone by policy, and
/// required when submitting an application.
class Toda {
  const Toda({
    required this.id,
    required this.code,
    required this.name,
    this.barangayCode,
    this.zone,
    this.membersCount = 0,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final String? barangayCode;
  final String? zone;
  final int membersCount;
  final bool isActive;

  factory Toda.fromMap(Map<String, dynamic> map) {
    return Toda(
      id: (map['id'] ?? '').toString(),
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      barangayCode: map['barangay_code']?.toString(),
      zone: map['zone']?.toString(),
      membersCount: _asInt(map['members_count']) ?? 0,
      isActive: map['is_active'] == null ? true : map['is_active'] == true,
    );
  }
}

/// A barangay of the Municipality of Mabini (`public.barangays`).
class Barangay {
  const Barangay({required this.code, required this.name});

  final String code;
  final String name;

  factory Barangay.fromMap(Map<String, dynamic> map) {
    return Barangay(
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
    );
  }
}

/// Tolerant integer parsing: PostgREST returns `smallint`/`integer` as `int`,
/// but a value read from JSON or a fixture may arrive as `double` or `String`.
int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
