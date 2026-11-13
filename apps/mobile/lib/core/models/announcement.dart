/// A published office announcement (`public.announcements`).
///
/// Staff and administrators author announcements in the web console; publishing
/// fans the content out into `public.notifications` through a SECURITY DEFINER
/// function. The mobile app reads the announcement rows directly — RLS only
/// returns published rows addressed to the signed-in driver — so the full text
/// is always available even when the notification has been cleared.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    this.publishedAt,
    this.createdAt,
    this.authorName,
  });

  final String id;
  final String title;
  final String body;

  /// `all_drivers`, `all_members`, `toda` or `drivers`.
  final String audience;

  final DateTime? publishedAt;
  final DateTime? createdAt;

  /// Display name of the staff member who published it, when the server
  /// includes the embedded profile.
  final String? authorName;

  factory Announcement.fromMap(Map<String, dynamic> map) {
    final author = map['author'];
    return Announcement(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      audience: (map['audience'] ?? 'all_drivers').toString(),
      publishedAt: _asDate(map['published_at']),
      createdAt: _asDate(map['created_at']),
      authorName: author is Map<String, dynamic>
          ? author['full_name']?.toString()
          : map['author_name']?.toString(),
    );
  }
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
