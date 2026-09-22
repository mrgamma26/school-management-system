import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../widgets/app_shell.dart';
import '../../../core/navigation/nav_items.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import 'dashboard_scaffold.dart';

class HeadTeacherDashboard extends ConsumerWidget {
  const HeadTeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return AppShell(
      navItems: getNavItemsForRole(user?.roleName ?? 'GUEST'),
      homeRoute: '/headteacher/home',
      body: DashboardBody(
        subtitle: 'Oversee academics, reviews, grades and school performance',
        roleIcon: Icons.supervisor_account,
        roleColor: AppColors.roleHeadTeacher,
        children: [
          DashGrid(
            sectionTitle: 'Reviews & Decisions',
            sectionIcon: Icons.rate_review,
            tiles: [
              _T(
                'Progression Reviews',
                Icons.trending_up,
                AppColors.success,
                () => context.go('/progression/reviews'),
              ),
              _T(
                'Weeding Reviews',
                Icons.filter_alt,
                AppColors.error,
                () => context.go('/weeding/reviews'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Academic Oversight',
            sectionIcon: Icons.school,
            tiles: [
              _T(
                'Assessments',
                Icons.quiz,
                AppColors.primary,
                () => context.go('/assessments'),
              ),
              _T(
                'Class Assignments',
                Icons.assignment_ind,
                AppColors.roleAdmin,
                () => context.go('/academics/assignments'),
              ),
              _T(
                'Students',
                Icons.groups,
                AppColors.roleHeadTeacher,
                () => context.go('/students'),
              ),
              _T(
                'Classes',
                Icons.class_,
                AppColors.secondary,
                () => context.go('/academics/classes'),
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
                AppColors.roleTeacher,
                () => context.go('/users/staff'),
              ),
              _T(
                'Guardians',
                Icons.family_restroom,
                AppColors.roleGuardian,
                () => context.go('/users/guardians'),
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
                'Student Comments',
                Icons.comment,
                AppColors.roleTeacher,
                () => context.go('/teacher/comments'),
              ),
              _T(
                'Reports',
                Icons.analytics,
                AppColors.roleAdmin,
                () => context.go('/reports'),
              ),
              _T(
                'Calendar',
                Icons.calendar_month,
                AppColors.accent,
                () => context.go('/calendar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _T = TileData;
