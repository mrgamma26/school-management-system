import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/dashboards/presentation/teacher_dashboard.dart';

class _TeacherAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: AppUser(
      userId: 'teacher',
      username: 'Teacher',
      roleId: 'role',
      roleName: 'TEACHER',
      mustChangePassword: false,
      isActive: true,
    ),
  );
}

void main() {
  testWidgets('teacher can open the assessments workspace from the shortcut', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/teacher/home',
      routes: [
        GoRoute(
          path: '/teacher/home',
          builder: (context, state) => const TeacherDashboard(),
        ),
        GoRoute(
          path: '/assessments',
          builder: (context, state) =>
              const Scaffold(body: Text('Assessments workspace')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TeacherAuth.new),
          permissionsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Assessment'), findsOneWidget);

    await tester.tap(find.text('Add Assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Assessments workspace'), findsOneWidget);
  });
}
