import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/models/profile.dart';

void main() {
  group('Profile.fullName', () {
    test('uses the generated full_name column when present', () {
      final profile = Profile(
        id: 'p1',
        role: 'driver',
        firstName: 'Juan',
        middleName: 'Perez',
        lastName: 'Dela Cruz',
        computedFullName: 'Juan Perez Dela Cruz',
        email: 'juan@example.com',
      );

      expect(profile.fullName, 'Juan Perez Dela Cruz');
    });

    test('falls back to first + middle + last when the column is absent', () {
      final profile = Profile(
        id: 'p1',
        role: 'driver',
        firstName: 'Juan',
        middleName: 'Perez',
        lastName: 'Dela Cruz',
        computedFullName: null,
        email: 'juan@example.com',
      );

      expect(profile.fullName, 'Juan Perez Dela Cruz');
    });
  });

  group('Profile flags', () {
    test('isDriver and isActive reflect role and account status', () {
      const driver = Profile(
        id: 'p1',
        role: 'driver',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        email: 'juan@example.com',
        accountStatus: 'active',
      );
      const staff = Profile(
        id: 'p2',
        role: 'staff',
        firstName: 'Ana',
        lastName: 'Reyes',
        email: 'ana@example.com',
        accountStatus: 'inactive',
      );

      expect(driver.isDriver, isTrue);
      expect(driver.isActive, isTrue);
      expect(staff.isDriver, isFalse);
      expect(staff.isActive, isFalse);
    });
  });

  group('Profile.fromMap', () {
    test('parses a row and derives initials', () {
      final profile = Profile.fromMap({
        'id': 'abc',
        'auth_user_id': 'user-1',
        'role': 'driver',
        'first_name': 'Juan',
        'middle_name': null,
        'last_name': 'Dela Cruz',
        'full_name': null,
        'email': 'juan@example.com',
        'contact_number': '09171234567',
        'account_status': 'active',
      });

      expect(profile.id, 'abc');
      expect(profile.authUserId, 'user-1');
      expect(profile.role, 'driver');
      expect(profile.fullName, 'Juan Dela Cruz');
      expect(profile.initials, 'JD');
      expect(profile.isDriver, isTrue);
      expect(profile.isActive, isTrue);
    });

    test('parses the TODA, barangay and address embedded in the profile query', () {
      final profile = Profile.fromMap({
        'id': 'abc',
        'role': 'driver',
        'first_name': 'Juan',
        'last_name': 'Dela Cruz',
        'email': 'juan@example.com',
        'contact_number': '09171234567',
        'address_line': 'Purok 2',
        'barangay_code': '137404001',
        'toda_id': 'toda-1',
        'created_at': '2025-06-01T08:00:00Z',
        'account_status': 'active',
        'toda': {'id': 'toda-1', 'name': 'TODA San Juan', 'code': 'TODA-001'},
        'barangay': {'code': '137404001', 'name': 'San Juan'},
      });

      expect(profile.addressLine, 'Purok 2');
      expect(profile.barangayCode, '137404001');
      expect(profile.barangayName, 'San Juan');
      expect(profile.todaId, 'toda-1');
      expect(profile.todaName, 'TODA San Juan');
      expect(profile.todaCode, 'TODA-001');
      expect(profile.createdAt, DateTime.parse('2025-06-01T08:00:00Z'));
    });
  });
}
