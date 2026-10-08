import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/auth/school_role_access.dart';
import 'package:school_management_app/core/navigation/nav_items.dart';
import 'package:school_management_app/core/navigation/role_menus.dart';

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
    expect(canManageSchoolCalendar('UNKNOWN'), isFalse);
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
}
