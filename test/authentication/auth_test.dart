import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';
import 'package:school_management_app/features/authentication/domain/models/app_role.dart';

void main() {
  group('AppRole', () {
    test('parses from JSON correctly', () {
      final json = {
        'roleid': 'role-uuid-001',
        'rolename': 'TEACHER',
        'description': 'Manages assessments and grades',
      };
      final role = AppRole.fromJson(json);
      expect(role.roleId, 'role-uuid-001');
      expect(role.roleName, 'TEACHER');
      expect(role.description, 'Manages assessments and grades');
    });

    test('description can be null', () {
      final role = AppRole.fromJson({
        'roleid': 'role-uuid-002',
        'rolename': 'GUARDIAN',
        'description': null,
      });
      expect(role.description, isNull);
    });
  });

  group('AppUser', () {
    test('parses from JSON correctly', () {
      final json = {
        'userid': 'user-uuid-001',
        'username': 'jdoe@school.edu',
        'roleid': 'role-uuid-001',
        'mustchangepassword': false,
        'isactive': true,
        'role': {'rolename': 'TEACHER'},
      };
      final user = AppUser.fromJson(json);
      expect(user.userId, 'user-uuid-001');
      expect(user.username, 'jdoe@school.edu');
      expect(user.roleName, 'TEACHER');
      expect(user.mustChangePassword, isFalse);
      expect(user.isActive, isTrue);
    });

    test('mustChangePassword flag is read correctly', () {
      final json = {
        'userid': 'user-uuid-002',
        'username': 'newuser@school.edu',
        'roleid': 'role-uuid-001',
        'mustchangepassword': true,
        'isactive': true,
        'role': {'rolename': 'REGISTRAR'},
      };
      final user = AppUser.fromJson(json);
      expect(user.mustChangePassword, isTrue);
    });
  });
}
