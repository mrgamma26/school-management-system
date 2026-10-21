import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/auth/school_role_access.dart';
import 'package:school_management_app/core/navigation/role_menus.dart';
import 'package:school_management_app/core/router.dart';

const _allRoles = [
  'SUPER_USER',
  'ADMINISTRATOR',
  'HEAD_TEACHER',
  'TEACHER',
  'ACCOUNTANT',
  'GUARDIAN',
];

Iterable<String> _routes(List<MenuNode> nodes) sync* {
  for (final node in nodes) {
    if (node.route != null) yield node.route!;
    yield* _routes(node.children);
  }
}

void main() {
  test('profile and help open for every role, including legacy admin', () {
    for (final role in [..._allRoles, 'SYSTEM_ADMIN']) {
      expect(isRouteAllowedForRole(role, '/profile'), isTrue, reason: role);
      expect(isRouteAllowedForRole(role, '/help'), isTrue, reason: role);
    }
    expect(isRouteAllowedForRole('UNKNOWN', '/profile'), isFalse);
    expect(isRouteAllowedForRole('UNKNOWN', '/help'), isFalse);
  });

  test('roles map and Supabase setup are Super User only', () {
    for (final path in ['/admin/roles-map', '/admin/supabase-setup']) {
      for (final role in [..._allRoles, 'SYSTEM_ADMIN']) {
        expect(
          isRouteAllowedForRole(role, path),
          role == 'SUPER_USER' || role == 'SYSTEM_ADMIN',
          reason: '$role on $path',
        );
      }
    }
    expect(canViewSystemGuides('SUPER_USER'), isTrue);
    expect(canViewSystemGuides('ADMINISTRATOR'), isFalse);
  });

  test('lookalike paths do not borrow the shared account access', () {
    expect(isRouteAllowedForRole('GUARDIAN', '/profile/other'), isFalse);
    expect(isRouteAllowedForRole('GUARDIAN', '/helpdesk'), isFalse);
  });

  test('every role menu offers Help and My Profile', () {
    for (final role in _allRoles) {
      final routes = _routes(roleMenus[role]!).toList();
      expect(routes, containsAll(['/help', '/profile']), reason: role);
    }
  });

  test('only the Super User menu links the system guidance pages', () {
    for (final role in _allRoles) {
      final routes = _routes(roleMenus[role]!).toList();
      expect(
        routes.contains('/admin/roles-map'),
        role == 'SUPER_USER',
        reason: role,
      );
      expect(
        routes.contains('/admin/supabase-setup'),
        role == 'SUPER_USER',
        reason: role,
      );
    }
  });

  test('every new menu link is a route its role may open', () {
    const added = {
      '/help',
      '/profile',
      '/admin/roles-map',
      '/admin/supabase-setup',
    };
    for (final role in _allRoles) {
      for (final route in _routes(roleMenus[role]!)) {
        if (added.contains(route)) {
          expect(isRouteAllowedForRole(role, route), isTrue, reason: role);
        }
      }
    }
  });

  test('role labels are friendly', () {
    expect(schoolRoleLabel('HEAD_TEACHER'), 'Head Teacher');
    expect(schoolRoleLabel('system_admin'), 'Super User');
  });
}
