import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../widgets/app_shell.dart';
import '../../../core/navigation/nav_items.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import 'dashboard_scaffold.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return AppShell(
      navItems: getNavItemsForRole(user?.roleName ?? 'GUEST'),
      homeRoute: '/teacher/home',
      body: DashboardBody(
        subtitle:
            'Manage your classes, assessments, grades and student comments',
        roleIcon: Icons.school,
        roleColor: AppColors.roleTeacher,
        children: [
          DashGrid(
            sectionTitle: 'My Classes',
            sectionIcon: Icons.class_,
            tiles: [
              _T(
                'My Assignments',
                Icons.assignment_ind,
                AppColors.roleTeacher,
                () => context.go('/academics/assignments'),
              ),
              _T(
                'Students',
                Icons.groups,
                AppColors.roleAdmin,
                () => context.go('/students'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Assessments & Grades',
            sectionIcon: Icons.grade,
            tiles: [
              _T(
                'Assessments',
                Icons.quiz,
                AppColors.primary,
                () => context.go('/assessments'),
              ),
              _T(
                'Enter Grades',
                Icons.edit_note,
                AppColors.success,
                () => context.go('/assessments'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Communications',
            sectionIcon: Icons.campaign,
            tiles: [
              _T(
                'Student Comments',
                Icons.comment,
                AppColors.roleTeacher,
                () => context.go('/teacher/comments'),
              ),
              _T(
                'Notifications',
                Icons.notifications,
                AppColors.roleHeadTeacher,
                () => context.go('/notifications'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'More',
            sectionIcon: Icons.more_horiz,
            tiles: [
              _T(
                'Calendar',
                Icons.calendar_month,
                AppColors.roleAccountant,
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
