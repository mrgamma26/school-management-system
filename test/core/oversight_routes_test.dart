import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/auth/school_role_access.dart';
import 'package:school_management_app/core/navigation/role_menus.dart';
import 'package:school_management_app/core/router.dart';

Iterable<String> routes(List<MenuNode> nodes) sync* {
  for (final node in nodes) {
    if (node.route != null) yield node.route!;
    yield* routes(node.children);
  }
}

void main() {
  const allRoles = [
    'SUPER_USER',
    'ADMINISTRATOR',
    'HEAD_TEACHER',
    'TEACHER',
    'ACCOUNTANT',
    'GUARDIAN',
  ];

  test('result correction and publishing rules match the RPC roles', () {
    for (final role in allRoles) {
      expect(
        canViewResultCorrections(role),
        ['SUPER_USER', 'HEAD_TEACHER', 'TEACHER'].contains(role),
      );
      expect(
        canDecideResultCorrections(role),
        ['SUPER_USER', 'HEAD_TEACHER'].contains(role),
      );
      expect(canCompleteResultCorrections(role), role == 'TEACHER');
      expect(
        canPublishResults(role),
        ['SUPER_USER', 'HEAD_TEACHER'].contains(role),
      );
      expect(
        isRouteAllowedForRole(role, '/results/corrections'),
        canViewResultCorrections(role),
      );
      expect(
        isRouteAllowedForRole(role, '/results/publish'),
        canPublishResults(role),
      );
    }
    expect(canPublishResults('SYSTEM_ADMIN'), isTrue);
  });

  test('email log is Super User only; finance records are finance roles', () {
    for (final role in allRoles) {
      expect(
        isRouteAllowedForRole(role, '/admin/email-log'),
        role == 'SUPER_USER',
      );
      for (final path in [
        '/finance/deposit-slips',
        '/finance/arrangements',
      ]) {
        expect(
          isRouteAllowedForRole(role, path),
          ['SUPER_USER', 'ADMINISTRATOR', 'ACCOUNTANT'].contains(role),
        );
      }
    }
  });

  test('every new menu link is a route its role may open', () {
    const added = {
      '/results/corrections',
      '/results/publish',
      '/finance/deposit-slips',
      '/finance/arrangements',
      '/finance/reversals',
      '/admin/email-log',
    };
    for (final role in allRoles) {
      for (final route in routes(roleMenus[role]!)) {
        if (added.contains(route)) {
          expect(
            isRouteAllowedForRole(role, route),
            isTrue,
            reason: '$role has a menu link to $route it cannot open',
          );
        }
      }
    }
  });
}
