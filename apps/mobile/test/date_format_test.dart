import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/date_format.dart';

void main() {
  group('formatDate', () {
    test('renders a local calendar date', () {
      expect(formatDate(DateTime(2026, 10, 15)), '15 Oct 2026');
      expect(formatDate(DateTime(2026, 1, 1)), '1 Jan 2026');
      expect(formatDate(DateTime(2026, 12, 31)), '31 Dec 2026');
    });

    test('renders an em dash for a missing date', () {
      expect(formatDate(null), '—');
    });
  });

  group('formatDateTime', () {
    test('renders a 12-hour clock with a padded minute', () {
      expect(
        formatDateTime(DateTime(2026, 10, 15, 14, 30)),
        '15 Oct 2026, 2:30 PM',
      );
      expect(
        formatDateTime(DateTime(2026, 10, 15, 9, 5)),
        '15 Oct 2026, 9:05 AM',
      );
    });

    test('renders midnight and noon on the 12-hour clock', () {
      expect(
        formatDateTime(DateTime(2026, 10, 15, 0, 0)),
        '15 Oct 2026, 12:00 AM',
      );
      expect(
        formatDateTime(DateTime(2026, 10, 15, 12, 0)),
        '15 Oct 2026, 12:00 PM',
      );
    });

    test('renders an em dash for a missing date', () {
      expect(formatDateTime(null), '—');
    });
  });
}
