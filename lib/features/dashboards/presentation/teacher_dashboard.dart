import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_shell.dart';
import 'dashboard_charts.dart';
import 'dashboard_scaffold.dart';

/// Screen 5 - Teacher dashboard.
class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      homeRoute: '/teacher/home',
      body: RoleDashboard(
        kicker: '',
        title: 'Teacher Dashboard',
        subtitle: '',
        charts: teacherCharts(),
        quickStart: const [
          DashboardLink(
            'Enter Marks',
            Icons.edit_note_outlined,
            '/assessments',
            detail: 'Record and submit class marks',
          ),
          DashboardLink(
            'Student Comments',
            Icons.comment_outlined,
            '/teacher/comments',
            detail: 'Write term feedback for learners',
          ),
          DashboardLink(
            'My Classes',
            Icons.assignment_ind_outlined,
            '/academics/assignments',
            detail: 'Your class-subject assignments',
          ),
        ],
        queueRole: 'TEACHER',
        metrics: [
          DashboardMetric.table(
            icon: Icons.class_outlined,
            label: 'Class-subject assignments',
            table: 'teacher_assignments',
            note: 'Assigned to you',
            route: '/academics/assignments',
          ),
          DashboardMetric.table(
            icon: Icons.quiz_outlined,
            label: 'Assessments',
            table: 'assessment',
            note: 'You can see',
            route: '/assessments',
          ),
          DashboardMetric.table(
            icon: Icons.groups_outlined,
            label: 'Students',
            table: 'student',
            note: 'In your classes',
            route: '/students',
          ),
          DashboardMetric.table(
            icon: Icons.comment_outlined,
            label: 'Comments written',
            table: 'teachercomment',
            note: 'Term feedback',
            route: '/teacher/comments',
          ),
        ],
        queueTitle: 'Teaching workboard',
        queueNote: 'Your fastest paths',
        queue: const [
          DashboardLink(
            'Assigned classes',
            Icons.class_outlined,
            '/academics/assignments',
            detail: 'Open your current class-subject assignments',
          ),
          DashboardLink(
            'Assessment work',
            Icons.edit_note_outlined,
            '/assessments',
            detail: 'Create assessments and enter marks',
          ),
          DashboardLink(
            'Learner comments',
            Icons.comment_outlined,
            '/teacher/comments',
            detail: 'Record concise term feedback',
          ),
        ],
        groups: const [
          DashboardGroup('Classes you teach', [
            DashboardLink(
              'Classes You Teach',
              Icons.assignment_ind_outlined,
              '/academics/assignments',
            ),
            DashboardLink('My Students', Icons.groups_outlined, '/students'),
          ]),
          DashboardGroup('Assessments & grades', [
            DashboardLink(
              'Add Assessment',
              Icons.add_task_outlined,
              '/assessments',
            ),
            DashboardLink(
              'Assessments & Grades',
              Icons.quiz_outlined,
              '/assessments',
            ),
          ]),
          DashboardGroup('Communications', [
            DashboardLink(
              'Teacher Comments',
              Icons.comment_outlined,
              '/teacher/comments',
            ),
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
