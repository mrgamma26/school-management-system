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
    final auth = ref.watch(authProvider);
    final user = auth.user;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: auth.isLoading
              ? const CircularProgressIndicator()
              : Text(auth.errorMessage ?? 'Unable to load your account.'),
        ),
      );
    }

    final activeRole = ref.watch(activeWorkspaceRoleProvider);
    final selectedRole = activeRole.isEmpty ? user.roleName : activeRole;
    switch ((selectedRole.trim().toUpperCase() == 'SYSTEM_ADMIN'
        ? 'SUPER_USER'
        : selectedRole.trim().toUpperCase())) {
      case 'SUPER_USER':
        return const AdminDashboard();
      case 'ADMINISTRATOR':
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
