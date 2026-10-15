import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/notification_format.dart';

void main() {
  group('notificationTypeLabel', () {
    test('maps the known types to their web-console labels', () {
      expect(
        notificationTypeLabel('application_approved'),
        'Application approved',
      );
      expect(notificationTypeLabel('document_rejected'), 'Document rejected');
      expect(notificationTypeLabel('renewal_reminder'), 'Renewal reminder');
      expect(notificationTypeLabel('application_under_review'),
          'Application under review');
      expect(notificationTypeLabel('system'), 'System');
    });

    test('humanises a type this build does not know yet', () {
      expect(
        notificationTypeLabel('application_on_hold'),
        'Application On Hold',
      );
    });

    test('falls back gracefully for an empty type', () {
      expect(notificationTypeLabel(''), 'Notification');
    });

    test('every known type has a label and no raw underscore', () {
      for (final entry in notificationTypeLabels.entries) {
        expect(notificationTypeLabel(entry.key), entry.value);
        expect(entry.value.contains('_'), isFalse);
      }
    });
  });
}
