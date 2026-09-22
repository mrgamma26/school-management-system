import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../widgets/app_shell.dart';
import '../../../core/navigation/nav_items.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import 'dashboard_scaffold.dart';

class AdministratorDashboard extends ConsumerWidget {
  const AdministratorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return AppShell(
      navItems: getNavItemsForRole(user?.roleName ?? 'GUEST'),
      homeRoute: '/administrator/home',
      body: DashboardBody(
        subtitle: 'Manage students, enrolment, guardians and school records',
        roleIcon: Icons.assignment_ind,
        roleColor: AppColors.roleAdmin,
        children: [
          DashGrid(
            sectionTitle: 'Students',
            sectionIcon: Icons.people_outline,
            tiles: [
              _T(
                'All Students',
                Icons.groups,
                AppColors.roleAdmin,
                () => context.go('/students'),
              ),
              _T(
                'Enrol Student',
                Icons.person_add_alt,
                AppColors.success,
                () => context.go('/students/new'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Guardians',
            sectionIcon: Icons.family_restroom,
            tiles: [
              _T(
                'Guardians',
                Icons.family_restroom,
                AppColors.roleGuardian,
                () => context.go('/users/guardians'),
              ),
              _T(
                'Add Guardian',
                Icons.person_add,
                AppColors.roleTeacher,
                () => context.go('/users/guardians/new'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Staff',
            sectionIcon: Icons.badge,
            tiles: [
              _T(
                'Staff List',
                Icons.badge,
                AppColors.roleHeadTeacher,
                () => context.go('/users/staff'),
              ),
              _T(
                'Add Staff',
                Icons.person_add,
                AppColors.roleSuperUser,
                () => context.go('/users/staff/new'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Academic Structure',
            sectionIcon: Icons.school,
            tiles: [
              _T(
                'Academic Years',
                Icons.calendar_today,
                AppColors.primary,
                () => context.go('/academics/years'),
              ),
              _T(
                'Classes',
                Icons.class_,
                AppColors.secondary,
                () => context.go('/academics/classes'),
              ),
              _T(
                'Subjects',
                Icons.book,
                AppColors.accent,
                () => context.go('/academics/subjects'),
              ),
              _T(
                'Assignments',
                Icons.assignment_ind,
                AppColors.roleAccountant,
                () => context.go('/academics/assignments'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Communications & Reports',
            sectionIcon: Icons.campaign,
            tiles: [
              _T(
                'Notifications',
                Icons.notifications,
                AppColors.roleHeadTeacher,
                () => context.go('/notifications'),
              ),
              _T(
                'Calendar',
                Icons.calendar_month,
                AppColors.accent,
                () => context.go('/calendar'),
              ),
              _T(
                'Reports',
                Icons.analytics,
                AppColors.roleAdmin,
                () => context.go('/reports'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _T = TileData;
