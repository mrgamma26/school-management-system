import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/router.dart' show homeForRole;
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../users/domain/models/staff.dart';
import '../providers/profile_providers.dart';

/// The signed-in user's own profile: identity, active role, optional staff
/// details and account options. Nothing here edits other data.
class MyProfilePage extends ConsumerWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const UiPage(
        children: [
          UiEmptyState(
            icon: Icons.person_outline_rounded,
            title: 'Not signed in',
          ),
        ],
      );
    }

    final workspaceRole = ref.watch(activeWorkspaceRoleProvider);
    final activeRole = schoolRole(
      workspaceRole.isEmpty ? user.roleName : workspaceRole,
    );
    final staff = ref
        .watch(myStaffProfileProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final otherRole = user.hasWorkspaceSwitcher
        ? (activeRole == 'TEACHER' ? 'HEAD_TEACHER' : 'TEACHER')
        : null;

    return UiPage(
      children: [
        const PageHead(
          kicker: 'System',
          title: 'My Profile',
          subtitle: 'Personal details, active role and secure account options.',
        ),
        const SizedBox(height: 16),
        ProfileHero(
          name: staff?.fullName.isNotEmpty == true
              ? staff!.fullName
              : user.username,
          subtitle: schoolRoleLabel(activeRole),
          pill: StatusPill(
            user.isActive ? 'Active' : 'Inactive',
            tone: user.isActive ? StatusTone.success : StatusTone.danger,
          ),
        ),
        const SizedBox(height: 16),
        SplitLayout(
          mainFlex: 1,
          sideFlex: 1,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel(
                title: 'Account',
                child: Column(
                  children: [
                    DetailLine('Username', user.username),
                    DetailLine('Active role', schoolRoleLabel(activeRole)),
                    if (otherRole != null)
                      DetailLine(
                        'Other available role',
                        schoolRoleLabel(otherRole),
                      ),
                  ],
                ),
              ),
              if (staff != null) ...[
                const SizedBox(height: 14),
                _StaffPanel(staff: staff),
              ],
            ],
          ),
          side: Panel(
            title: 'Account options',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (otherRole != null) ...[
                  UiButton.secondary(
                    'Switch to ${schoolRoleLabel(otherRole)} workspace',
                    icon: Icons.swap_horiz_rounded,
                    expand: true,
                    onPressed: () {
                      ref
                          .read(activeWorkspaceRoleProvider.notifier)
                          .switchTo(otherRole);
                      context.go(homeForRole(otherRole));
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                UiButton.secondary(
                  'Change password',
                  icon: Icons.lock_outline_rounded,
                  expand: true,
                  onPressed: () => context.go('/change-password'),
                ),
                const SizedBox(height: 10),
                UiButton(
                  'Sign out',
                  icon: Icons.logout_rounded,
                  kind: UiButtonKind.danger,
                  expand: true,
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffPanel extends StatelessWidget {
  final Staff staff;
  const _StaffPanel({required this.staff});

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final lines = <(String, String?)>[
      ('Employee number', _clean(staff.employeeNumber)),
      ('Email', _clean(staff.email)),
      ('Phone', _clean(staff.phoneNumber)),
      ('Job title', _clean(staff.jobTitle)),
      ('Department', _clean(staff.department)),
      ('Employment type', _clean(staff.employmentType)),
      ('Employment status', _clean(staff.employmentStatus)),
      (
        'Employment start',
        staff.employmentStartDate == null
            ? null
            : formatUiDate(staff.employmentStartDate),
      ),
    ];
    return Panel(
      title: 'Staff profile',
      child: Column(
        children: [
          for (final line in lines)
            if (line.$2 != null) DetailLine(line.$1, line.$2!),
        ],
      ),
    );
  }
}
