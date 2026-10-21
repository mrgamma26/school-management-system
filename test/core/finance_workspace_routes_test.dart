import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/navigation/role_menus.dart';
import 'package:school_management_app/core/router.dart';

Iterable<String> routes(List<MenuNode> nodes) sync* {
  for (final node in nodes) {
    if (node.route != null) yield node.route!;
    yield* routes(node.children);
  }
}

void main() {
  const roles = [
    'SUPER_USER',
    'ADMINISTRATOR',
    'HEAD_TEACHER',
    'TEACHER',
    'ACCOUNTANT',
    'GUARDIAN',
  ];

  test('student accounts and overdue accounts are Accountant only', () {
    for (final role in roles) {
      for (final path in ['/finance/accounts', '/finance/overdue']) {
        expect(isRouteAllowedForRole(role, path), role == 'ACCOUNTANT');
      }
    }
  });

  test('child workspace is for guardians only', () {
    for (final role in roles) {
      expect(
        isRouteAllowedForRole(role, '/guardian/child'),
        role == 'GUARDIAN' || role == 'SUPER_USER',
      );
    }
  });

  test('menus link the new workspaces', () {
    final accountant = routes(menuForRole('ACCOUNTANT', const {})).toList();
    expect(accountant, containsAll(['/finance/accounts', '/finance/overdue']));
    final guardian = routes(menuForRole('GUARDIAN', const {})).toList();
    expect(guardian, contains('/guardian/child'));
    for (final route in accountant) {
      expect(isRouteAllowedForRole('ACCOUNTANT', route), isTrue, reason: route);
    }
    for (final route in guardian) {
      expect(isRouteAllowedForRole('GUARDIAN', route), isTrue, reason: route);
    }
  });
}
