import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/constants.dart';
import 'package:sbtf_mobile/core/models/app_notification.dart';
import 'package:sbtf_mobile/core/models/application_event.dart';
import 'package:sbtf_mobile/core/models/certificate_verification.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';
import 'package:sbtf_mobile/core/models/franchise_document.dart';
import 'package:sbtf_mobile/core/models/franchise_record.dart';
import 'package:sbtf_mobile/core/models/toda.dart';

void main() {
  group('domain constants', () {
    test('every required document type has a label', () {
      expect(requiredDocumentTypes, hasLength(4));
      for (final type in requiredDocumentTypes) {
        expect(documentLabels.containsKey(type), isTrue);
        expect(documentShortLabels.containsKey(type), isTrue);
      }
    });
  });

  group('Toda.fromMap', () {
    test('parses a row and tolerates a string member count', () {
      final toda = Toda.fromMap({
        'id': 't1',
        'code': 'T-01',
        'name': 'San Juan TODA',
        'barangay_code': '13401',
        'zone': 'Zone 2',
        'members_count': '42',
        'is_active': null,
      });

      expect(toda.id, 't1');
      expect(toda.code, 'T-01');
      expect(toda.membersCount, 42);
      expect(toda.isActive, isTrue);
    });
  });

  group('Barangay.fromMap', () {
    test('reads the code and name', () {
      final barangay = Barangay.fromMap({'code': '13401', 'name': 'San Juan'});

      expect(barangay.code, '13401');
      expect(barangay.name, 'San Juan');
    });
  });

  group('FranchiseDocument', () {
    test('parses metadata and resolves labels', () {
      final document = FranchiseDocument.fromMap({
        'id': 'd1',
        'application_id': 'a1',
        'document_type': 'or_cr',
        'storage_path': 'profile-1/a1/or_cr-1.pdf',
        'file_name': 'or_cr.pdf',
        'file_size_bytes': '2048',
        'mime_type': 'application/pdf',
        'verification_status': 'rejected',
        'remarks': 'Illegible',
        'uploaded_at': '2026-01-01T00:00:00Z',
      });

      expect(document.id, 'd1');
      expect(document.fileSizeBytes, 2048);
      expect(document.isRejected, isTrue);
      expect(document.canReplace, isTrue);
      expect(document.label, documentLabels['or_cr']);
      expect(document.shortLabel, documentShortLabels['or_cr']);
    });

    test('a verified document cannot be replaced', () {
      final document = FranchiseDocument.fromMap({
        'id': 'd2',
        'application_id': 'a1',
        'document_type': 'cedula',
        'storage_path': 'profile-1/a1/cedula-1.png',
        'file_name': 'cedula.png',
        'verification_status': 'verified',
      });

      expect(document.isVerified, isTrue);
      expect(document.canReplace, isFalse);
    });
  });

  group('ApplicationEvent.label', () {
    test('maps the known workflow events', () {
      ApplicationEvent eventWith(String event) => ApplicationEvent(
            id: 'e1',
            applicationId: 'a1',
            event: event,
          );

      expect(eventWith('created').label, 'Application submitted');
      expect(eventWith('certificate_issued').label, 'Certificate issued');
      expect(eventWith('rejected').label, 'Application rejected');
    });

    test('humanises an unknown event', () {
      final event = ApplicationEvent(
        id: 'e1',
        applicationId: 'a1',
        event: 'some_new_event',
      );

      expect(event.label, 'some new event');
    });
  });

  group('FranchiseRecord.fromMap', () {
    final now = DateTime.now();

    FranchiseRecord recordWith({
      bool archived = false,
      Duration untilExpiry = const Duration(days: 200),
    }) {
      return FranchiseRecord(
        id: 'r1',
        applicationId: 'a1',
        operatorId: 'o1',
        todaId: 't1',
        franchiseNumber: 'FR-2026-001',
        verificationCode: 'ABCDEFGHJKLM',
        issuedAt: now,
        expiresAt: now.add(untilExpiry),
        archived: archived,
      );
    }

    test('parses joined relations and dates', () {
      final record = FranchiseRecord.fromMap({
        'id': 'r1',
        'application_id': 'a1',
        'operator_id': 'o1',
        'toda_id': 't1',
        'franchise_number': 'FR-2026-001',
        'verification_code': 'ABCDEFGHJKLM',
        'issued_at': '2026-01-01T00:00:00Z',
        'expires_at': '2027-01-01T00:00:00Z',
        'certificate_storage_path': 'p/o1/r1.pdf',
        'toda': {'name': 'San Juan TODA'},
        'operator': {'full_name': 'Juan Dela Cruz'},
        'application': {
          'plate_number': 'ABC 123',
          'vehicle_make': 'Honda',
          'vehicle_model': 'TMX',
          'vehicle_year': 2020,
        },
      });

      expect(record.todaName, 'San Juan TODA');
      expect(record.operatorName, 'Juan Dela Cruz');
      expect(record.plateNumber, 'ABC 123');
      expect(record.vehicleYear, 2020);
      expect(record.hasCertificate, isTrue);
      expect(record.vehicleDescription, 'Honda TMX (2020)');
    });

    test('reports the coarse state', () {
      expect(recordWith().state, 'active');
      expect(
          recordWith(untilExpiry: const Duration(days: 30)).state, 'expiring');
      expect(
        recordWith(untilExpiry: const Duration(days: -10)).state,
        'expired',
      );
      expect(recordWith(archived: true).state, 'archived');
    });

    test('an expired or archived record is never expiring soon', () {
      expect(
        recordWith(untilExpiry: const Duration(days: -1)).isExpiringSoon,
        isFalse,
      );
      expect(
        recordWith(archived: true, untilExpiry: const Duration(days: 10))
            .isExpiringSoon,
        isFalse,
      );
    });

    test('daysRemaining goes negative once expired', () {
      expect(
        recordWith(untilExpiry: const Duration(days: -10)).daysRemaining,
        lessThan(0),
      );
    });
  });

  group('CertificateVerification', () {
    test('parses a valid result', () {
      final result = CertificateVerification.fromMap({
        'verification_status': 'valid',
        'franchise_number': 'FR-2026-001',
        'operator_display_name': 'J*** D*** C***',
        'toda_name': 'San Juan TODA',
        'issued_at': '2026-01-01T00:00:00Z',
        'expires_at': '2027-01-01T00:00:00Z',
      });

      expect(result.isValid, isTrue);
      expect(result.statusLabel, 'Valid franchise');
      expect(result.operatorDisplayName, 'J*** D*** C***');
    });

    test('labels the non-valid outcomes', () {
      expect(
        CertificateVerification.fromMap({'verification_status': 'expired'})
            .statusLabel,
        'Expired franchise',
      );
      expect(
        CertificateVerification.fromMap({'verification_status': 'archived'})
            .statusLabel,
        'Archived franchise',
      );
      expect(CertificateVerification.notFound().statusLabel,
          'Certificate not found');
      expect(CertificateVerification.notFound().isValid, isFalse);
    });
  });

  group('AppNotification', () {
    test('parses a row and resolves deep-link targets', () {
      final notification = AppNotification.fromMap({
        'id': 'n1',
        'user_id': 'u1',
        'title': 'Application approved',
        'message': 'Your franchise has been approved.',
        'notification_type': 'application_approved',
        'target_type': 'franchise_application',
        'target_id': 'a1',
        'read': true,
        'read_at': '2026-01-02T00:00:00Z',
      });

      expect(notification.read, isTrue);
      expect(notification.targetsApplication, isTrue);
      expect(notification.targetsRecord, isFalse);
    });

    test('defaults to the system type and unread', () {
      final notification = AppNotification.fromMap({
        'id': 'n2',
        'user_id': 'u1',
        'title': 'Hello',
        'message': 'World',
      });

      expect(notification.notificationType, 'system');
      expect(notification.read, isFalse);
      expect(notification.targetsApplication, isFalse);
    });
  });

  group('FranchiseApplication', () {
    Map<String, dynamic> rawApplication() => {
          'id': 'a1',
          'application_number': 'APP-2026-001',
          'applicant_id': 'u1',
          'application_type': 'new',
          'status': 'pending',
          'toda_id': 't1',
          'operator_first_name': 'Juan',
          'operator_middle_name': 'Perez',
          'operator_last_name': 'Dela Cruz',
          'operator_contact_number': '09171234567',
          'operator_address_line': 'Purok 1',
          'vehicle_make': 'Honda',
          'vehicle_model': 'TMX',
          'vehicle_year': '2020',
          'vehicle_color': 'Blue',
          'plate_number': 'ABC 123',
          'engine_number': 'ENG12345',
          'chassis_number': 'CHS12345',
          'seating_capacity': 5,
          'toda': {'name': 'San Juan TODA'},
          'documents': [
            {
              'id': 'd2',
              'application_id': 'a1',
              'document_type': 'cedula',
              'storage_path': 'p/a1/cedula-1.png',
              'file_name': 'cedula.png',
            },
            {
              'id': 'd1',
              'application_id': 'a1',
              'document_type': 'or_cr',
              'storage_path': 'p/a1/or_cr-1.pdf',
              'file_name': 'or_cr.pdf',
            },
          ],
          'timeline': [
            {
              'id': 'e2',
              'application_id': 'a1',
              'event': 'review_started',
              'created_at': '2026-01-02T00:00:00Z',
            },
            {
              'id': 'e1',
              'application_id': 'a1',
              'event': 'created',
              'created_at': '2026-01-01T00:00:00Z',
            },
          ],
        };

    test('parses the row, relations and string integers', () {
      final application = FranchiseApplication.fromMap(rawApplication());

      expect(application.id, 'a1');
      expect(application.vehicleYear, 2020);
      expect(application.todaName, 'San Juan TODA');
      expect(application.documents, hasLength(2));
      expect(application.timeline, hasLength(2));
      expect(application.isPending, isTrue);
      expect(application.operatorFullName, 'Juan Perez Dela Cruz');
    });

    test('orders documents by the canonical requirement order', () {
      final application = FranchiseApplication.fromMap(rawApplication());

      expect(
        application.orderedDocuments
            .map((document) => document.documentType)
            .toList(),
        ['or_cr', 'cedula'],
      );
    });

    test('orders the timeline oldest-first', () {
      final application = FranchiseApplication.fromMap(rawApplication());

      expect(
        application.orderedTimeline.map((event) => event.event).toList(),
        ['created', 'review_started'],
      );
    });

    test('status helpers reflect the row', () {
      final approved = FranchiseApplication.fromMap(
        rawApplication()..['status'] = 'approved',
      );
      final rejected = FranchiseApplication.fromMap(
        rawApplication()..['status'] = 'rejected',
      );

      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);
      expect(rejected.isRejected, isTrue);
    });

    test('handles a flat row with no relations', () {
      final application = FranchiseApplication.fromMap({
        'id': 'a2',
        'status': 'pending',
      });

      expect(application.todaName, isNull);
      expect(application.documents, isEmpty);
      expect(application.timeline, isEmpty);
      expect(application.operatorFullName, '');
    });
  });
}
