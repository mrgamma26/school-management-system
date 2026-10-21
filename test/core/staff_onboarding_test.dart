import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/auth/school_role_access.dart';
import 'package:school_management_app/core/router.dart';
import 'package:school_management_app/features/users/domain/staff_onboarding.dart';
import 'package:school_management_app/features/users/presentation/pages/staff_form_page.dart';

void main() {
  test('staff account request carries the complete server contract', () {
    final request = buildStaffAccountRequest(
      roleId: 'accountant-role',
      temporaryPassword: 'Fixed!Pass123',
      profile: {
        'firstName': 'Mary',
        'lastName': 'Banda',
        'email': 'mary@example.test',
        'employeeNumber': 'EMP-42',
        'dateOfBirth': '1990-01-02',
        'phoneNumber': '+265991234567',
        'jobTitle': 'Accountant',
        'employmentType': 'FULL_TIME',
        'employmentStartDate': '2026-10-19',
        'emergencyContactName': 'John Banda',
        'emergencyContactPhone': '+265881234567',
        'emergencyContactRelationship': 'Sibling',
      },
    );

    expect(request['type'], 'staff');
    expect(request['userType'], 'STAFF');
    expect(request['password'], 'Fixed!Pass123');
    expect(request['roleId'], 'accountant-role');
    expect(request['profileData'], isA<Map<String, dynamic>>());
    expect(
      request['profileData'],
      containsPair('emergencyContactRelationship', 'Sibling'),
    );
    expect(request['profileData'], containsPair('jobTitle', 'Accountant'));
  });

  test(
    'generated temporary password includes every required character class',
    () {
      final password = generateSecureTemporaryPassword();
      expect(password, hasLength(12));
      expect(password, matches(RegExp('[A-Z]')));
      expect(password, matches(RegExp('[a-z]')));
      expect(password, matches(RegExp('[0-9]')));
      expect(password, matches(RegExp(r'[!@#$%&*]')));
    },
  );

  test('staff form accepts deterministic password generation for tests', () {
    const expected = 'Fixed!Pass123';
    final page = StaffFormPage(
      temporaryPasswordGenerator: () => expected,
    );
    expect(page.temporaryPasswordGenerator(), expected);
  });

  test('only teaching roles get the class assignment hand-off', () {
    expect(isTeachingRole('Teacher'), isTrue);
    expect(isTeachingRole('HEAD_TEACHER'), isTrue);
    expect(isTeachingRole('ACCOUNTANT'), isFalse);
    expect(isTeachingRole(null), isFalse);
  });

  test('dual Head Teacher role is Teacher-only and Super User-only', () {
    expect(
      canGrantHeadTeacherDualRole(
        selectedRoleName: 'TEACHER',
        actorRole: 'SUPER_USER',
      ),
      isTrue,
    );
    expect(
      canGrantHeadTeacherDualRole(
        selectedRoleName: 'TEACHER',
        actorRole: 'ADMINISTRATOR',
      ),
      isFalse,
    );
    expect(
      canGrantHeadTeacherDualRole(
        selectedRoleName: 'ACCOUNTANT',
        actorRole: 'SUPER_USER',
      ),
      isFalse,
    );
    expect(showsDualRoleControl('Teacher'), isTrue);
    expect(showsDualRoleControl('HEAD_TEACHER'), isFalse);
  });

  test('a new teacher is sent on to Class Setup', () {
    expect(classSetupRoute, '/academics/class-setup');
  });

  test('class setup is changed by setup roles and read by the head teacher', () {
    for (final role in ['SUPER_USER', 'ADMINISTRATOR']) {
      expect(canManageAcademicSetup(role), isTrue);
      expect(isRouteAllowedForRole(role, '/academics/class-setup'), isTrue);
    }
    // The Head Teacher opens it read-only; the page hides every action.
    expect(canManageAcademicSetup('HEAD_TEACHER'), isFalse);
    expect(
      isRouteAllowedForRole('HEAD_TEACHER', '/academics/class-setup'),
      isTrue,
    );
    for (final role in ['TEACHER', 'ACCOUNTANT', 'GUARDIAN']) {
      expect(isRouteAllowedForRole(role, '/academics/class-setup'), isFalse);
    }
    // Teachers keep their read-only "Classes You Teach" list.
    expect(isRouteAllowedForRole('TEACHER', '/academics/assignments'), isTrue);
  });
}
