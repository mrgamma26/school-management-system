import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../widgets/app_shell.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import 'dashboard_scaffold.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authProvider);
    return AppShell(
      homeRoute: '/teacher/home',
      body: DashboardBody(
        subtitle:
            'Manage your classes, assessments, grades and student comments',
        roleIcon: Icons.school,
        roleColor: AppColors.roleTeacher,
        children: [
          DashGrid(
            sectionTitle: 'Classes You Teach',
            sectionIcon: Icons.class_,
            tiles: [
              _T(
                'Classes You Teach',
                Icons.assignment_ind,
                AppColors.roleTeacher,
                () => context.go('/academics/assignments'),
              ),
              _T(
                'My Students',
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
                'Add Assessment',
                Icons.add_task,
                AppColors.roleTeacher,
                () => context.go('/assessments'),
              ),
              _T(
                'Assessments & Grades',
                Icons.quiz,
                AppColors.primary,
                () => context.go('/assessments'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Communications',
            sectionIcon: Icons.campaign,
            tiles: [
              _T(
                'Teacher Comments',
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
              _T(
                'Calendar',
                Icons.calendar_month,
                AppColors.roleAccountant,
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
