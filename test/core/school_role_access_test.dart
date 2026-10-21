import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/auth/school_role_access.dart';
import 'package:school_management_app/core/navigation/nav_items.dart';
import 'package:school_management_app/core/navigation/role_menus.dart';
import 'package:school_management_app/core/router.dart';

Iterable<String> routes(List<MenuNode> nodes) sync* {
  for (final node in nodes) {
    if (node.route != null) yield node.route!;
    yield* routes(node.children);
  }
}

void main() {
  for (final role in [
    'SUPER_USER',
    'ADMINISTRATOR',
    'HEAD_TEACHER',
    'TEACHER',
    'ACCOUNTANT',
    'GUARDIAN',
  ]) {
    test('$role has the intended calendar and review permissions', () {
      expect(
        canManageSchoolCalendar(role),
        ['SUPER_USER', 'ADMINISTRATOR'].contains(role),
      );
      expect(canAccessSchoolReviews(role), role == 'HEAD_TEACHER');
      expect(canRecordStudentPayments(role), role == 'ACCOUNTANT');
      expect(
        routes(roleMenus[role]!).any((r) => r.contains('/reviews')),
        role == 'HEAD_TEACHER',
      );
      expect(
        getNavItemsForRole(role).any((n) => n.route.contains('/reviews')),
        role == 'HEAD_TEACHER',
      );
    });
  }
  test('legacy system admin is normalized; unknown roles get no privilege', () {
    expect(canManageSchoolCalendar(' system_admin '), isTrue);
    expect(canAccessSchoolReviews('SYSTEM_ADMIN'), isFalse);
    expect(canRecordStudentPayments('SYSTEM_ADMIN'), isFalse);
    expect(canManageSchoolCalendar('UNKNOWN'), isFalse);
    expect(canRecordStudentPayments('UNKNOWN'), isFalse);
  });

  test('only accountants may open student payment workflows', () {
    expect(canRecordStudentPayments(' accountant '), isTrue);
    for (final role in [
      'SUPER_USER',
      'SYSTEM_ADMIN',
      'ADMINISTRATOR',
      'ADMIN',
      'HEAD_TEACHER',
      'TEACHER',
      'GUARDIAN',
    ]) {
      expect(
        canRecordStudentPayments(role),
        isFalse,
        reason: '$role must not record student payments',
      );
    }
  });

  test('student finance routes are accountant-only', () {
    for (final path in [
      '/finance/students/student-1/account',
      '/finance/students/student-1/pay',
    ]) {
      expect(isRouteAllowedForRole('ACCOUNTANT', path), isTrue);
      for (final role in [
        'SUPER_USER',
        'SYSTEM_ADMIN',
        'ADMINISTRATOR',
        'ADMIN',
        'HEAD_TEACHER',
        'TEACHER',
        'GUARDIAN',
      ]) {
        expect(
          isRouteAllowedForRole(role, path),
          isFalse,
          reason: '$role must not open $path',
        );
      }
    }

    expect(isRouteAllowedForRole('SUPER_USER', '/finance/payments'), isTrue);
    expect(
      isRouteAllowedForRole('ADMINISTRATOR', '/finance/payment-configuration'),
      isTrue,
    );
  });
  test('admin student menu always shows list and registration', () {
    for (final role in ['SUPER_USER', 'ADMINISTRATOR']) {
      final menu = menuForRole(role, {'students:enrol'});
      final students = menu.singleWhere((node) => node.label == 'Students');
      expect(students.isGroup, isTrue);
      expect(students.children.map((node) => node.route), [
        '/students',
        '/students/new',
      ]);
      final withoutEnrol = menuForRole(role, {});
      final studentLinks = withoutEnrol
          .singleWhere((node) => node.label == 'Students')
          .children;
      expect(studentLinks.map((node) => node.route), [
        '/students',
        '/students/new',
      ]);
    }
    expect(
      routes(roleMenus['HEAD_TEACHER']!).contains('/students/new'),
      isFalse,
    );
  });

  test('only leadership roles send notifications to guardians', () {
    for (final role in [
      'SUPER_USER',
      'SYSTEM_ADMIN',
      'ADMINISTRATOR',
      'HEAD_TEACHER',
    ]) {
      expect(canSendNotifications(role), isTrue, reason: role);
    }
    for (final role in ['TEACHER', 'ACCOUNTANT', 'GUARDIAN']) {
      expect(canSendNotifications(role), isFalse, reason: role);
    }
  });

  test('role-implied permissions mirror what row-level security allows', () {
    final superUser = impliedPermissionsFor('SUPER_USER');
    final admin = impliedPermissionsFor('ADMINISTRATOR');
    expect(
      superUser,
      containsAll(['users:read', 'auditlog:read', 'staff:write']),
    );
    expect(
      admin,
      containsAll([
        'staff:write',
        'guardians:write',
        'academics:write',
        'finance:manage_structures',
      ]),
    );
    // Only the Super User reads the audit log and the system user list.
    expect(admin, isNot(contains('auditlog:read')));
    expect(admin, isNot(contains('users:read')));
    expect(impliedPermissionsFor('SYSTEM_ADMIN'), superUser);
    for (final role in ['TEACHER', 'ACCOUNTANT', 'GUARDIAN', 'HEAD_TEACHER']) {
      expect(impliedPermissionsFor(role), isEmpty, reason: role);
    }
  });
}
