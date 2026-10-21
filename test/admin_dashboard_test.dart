import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/dashboards/presentation/admin_dashboard.dart';
import 'package:school_management_app/features/settings/domain/school_settings.dart';
import 'package:school_management_app/features/settings/presentation/settings_providers.dart';

class _AdminAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: AppUser(
      userId: 'admin',
      username: 'Admin',
      roleId: 'role',
      roleName: 'SUPER_USER',
      mustChangePassword: false,
      isActive: true,
    ),
  );
}

void main() {
  testWidgets('admin overview shows counts and opens academic year form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/admin/home',
      routes: [
        GoRoute(
          path: '/admin/home',
          builder: (context, state) => const AdminDashboard(),
        ),
        GoRoute(
          path: '/academics/years/new',
          builder: (context, state) =>
              const Scaffold(body: Text('Academic year form')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_AdminAuth.new),
          permissionsProvider.overrideWith((ref) async => {'students:enrol'}),
          schoolBrandingProvider.overrideWith(
            (ref) async => const SchoolBranding(schoolName: 'New School Name'),
          ),
          adminOverviewCountProvider('student').overrideWith((ref) async => 24),
          adminOverviewCountProvider('staff').overrideWith((ref) async => 8),
          adminOverviewCountProvider(
            'guardian',
          ).overrideWith((ref) async => 17),
          adminOverviewCountProvider(
            'systemuser',
          ).overrideWith((ref) async => 12),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    for (final count in ['24', '8', '17', '12']) {
      expect(find.text(count), findsOneWidget);
    }
    expect(find.text('New School Name'), findsOneWidget);
    expect(find.text('Management Portal'), findsNothing);
    // Charts now sit above the cards, so scroll the shortcut into view first.
    await tester.ensureVisible(find.text('Add Academic Year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Academic Year'));
    await tester.pumpAndSettle();
    expect(find.text('Academic year form'), findsOneWidget);
  });
}
