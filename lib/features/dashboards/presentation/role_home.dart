import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import 'admin_dashboard.dart';
import 'administrator_dashboard.dart';
import 'teacher_dashboard.dart';
import 'headteacher_dashboard.dart';
import 'accountant_dashboard.dart';
import 'guardian_dashboard.dart';

/// Dispatches to the correct dashboard based on the authenticated user's role.
class RoleHome extends ConsumerWidget {
  // [role] parameter kept for GoRouter compatibility but role is read from auth.
  final String role;
  const RoleHome(this.role, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    switch (user.roleName.trim().toUpperCase()) {
      case 'SUPER_USER':
      case 'SYSTEM_ADMIN':
        return const AdminDashboard();
      case 'ADMINISTRATOR':
      case 'REGISTRAR':
        return const AdministratorDashboard();
      case 'TEACHER':
        return const TeacherDashboard();
      case 'HEAD_TEACHER':
        return const HeadTeacherDashboard();
      case 'ACCOUNTANT':
        return const AccountantDashboard();
      case 'GUARDIAN':
        return const GuardianDashboard();
      default:
        return _UnknownRole(user.roleName);
    }
  }
}

class _UnknownRole extends StatelessWidget {
  final String role;
  const _UnknownRole(this.role);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No dashboard for role: $role',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
