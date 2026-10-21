import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_shell.dart';
import 'dashboard_charts.dart';
import 'dashboard_scaffold.dart';

/// Screen 4 - Head Teacher dashboard.
class HeadTeacherDashboard extends ConsumerWidget {
  const HeadTeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      homeRoute: '/headteacher/home',
      body: RoleDashboard(
        kicker: '',
        title: 'Head Teacher Dashboard',
        subtitle: '',
        charts: headTeacherCharts(),
        quickStart: const [
          DashboardLink(
            'Review Results',
            Icons.assignment_turned_in_outlined,
            '/results/review',
            detail: 'Approve submitted result sheets',
          ),
          DashboardLink(
            'Correction Requests',
            Icons.edit_note_outlined,
            '/results/corrections',
            detail: 'Decide on requested mark changes',
          ),
          DashboardLink(
            'Progression Review',
            Icons.trending_up_outlined,
            '/progression/reviews',
            detail: 'Promote or retain with a reason',
          ),
        ],
        queueRole: 'HEAD_TEACHER',
        metrics: [
          DashboardMetric.table(
            icon: Icons.school_outlined,
            label: 'Students',
            table: 'student',
            note: 'Registered learners',
            route: '/students',
          ),
          DashboardMetric.table(
            icon: Icons.class_outlined,
            label: 'Classes',
            table: 'class',
            note: 'Across all forms',
            route: '/academics/class-setup',
          ),
          DashboardMetric.table(
            icon: Icons.edit_note_outlined,
            label: 'Correction requests',
            table: 'result_correction_requests',
            note: 'Requests on record',
            route: '/results/corrections',
          ),
          DashboardMetric.table(
            icon: Icons.trending_up_outlined,
            label: 'Progression reviews',
            table: 'progressionreview',
            note: 'Reviews on record',
            route: '/progression/reviews',
          ),
        ],
        queueTitle: 'Academic approval queue',
        queueNote: 'Needs your decision',
        queue: const [
          DashboardLink(
            'Assessments and results',
            Icons.assignment_turned_in_outlined,
            '/results/review',
            detail: 'Review submitted academic records',
          ),
          DashboardLink(
            'Progression decisions',
            Icons.trending_up_outlined,
            '/progression/reviews',
            detail: 'Promote or retain with an audited reason',
          ),
          DashboardLink(
            'Student status reviews',
            Icons.manage_search_outlined,
            '/weeding/reviews',
            detail: 'Review weeding and intervention cases',
          ),
        ],
        groups: const [
          DashboardGroup('Reviews & decisions', [
            DashboardLink(
              'Progression Reviews',
              Icons.trending_up_outlined,
              '/progression/reviews',
            ),
            DashboardLink(
              'Student Status Reviews',
              Icons.filter_alt_outlined,
              '/weeding/reviews',
            ),
          ]),
          DashboardGroup('Academic oversight', [
            DashboardLink(
              'Results Review',
              Icons.quiz_outlined,
              '/results/review',
            ),
            DashboardLink(
              'Class Setup',
              Icons.account_tree_outlined,
              '/academics/class-setup',
            ),
            DashboardLink('Students', Icons.groups_outlined, '/students'),
          ]),
          DashboardGroup('People', [
            DashboardLink('Staff List', Icons.badge_outlined, '/users/staff'),
            DashboardLink(
              'Guardians',
              Icons.family_restroom_outlined,
              '/users/guardians',
            ),
          ]),
          DashboardGroup('Communications & reports', [
            DashboardLink(
              'Teacher Comments',
              Icons.comment_outlined,
              '/teacher/comments',
            ),
            DashboardLink('Reports', Icons.analytics_outlined, '/reports'),
            DashboardLink(
              'Calendar',
              Icons.calendar_month_outlined,
              '/calendar',
            ),
          ]),
        ],
      ),
    );
  }
}
