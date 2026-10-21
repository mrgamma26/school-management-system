import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_shell.dart';
import 'dashboard_charts.dart';
import 'dashboard_scaffold.dart';

/// Screen 3 - Administrator dashboard.
class AdministratorDashboard extends ConsumerWidget {
  const AdministratorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      homeRoute: '/administrator/home',
      body: RoleDashboard(
        kicker: '',
        title: 'Administrator Dashboard',
        subtitle: '',
        charts: administratorCharts(),
        quickStart: const [
          DashboardLink(
            'Register Student',
            Icons.person_add_alt,
            '/students/new',
            detail: 'Enrol a new learner',
          ),
          DashboardLink(
            'Class Setup',
            Icons.class_outlined,
            '/academics/class-setup',
            detail: 'Classes, subjects and teachers',
          ),
          DashboardLink(
            'Add Staff',
            Icons.person_add_alt_1_outlined,
            '/users/staff/new',
            detail: 'Create a staff profile',
          ),
        ],
        queueRole: 'ADMINISTRATOR',
        metrics: [
          DashboardMetric.table(
            icon: Icons.school_outlined,
            label: 'Students',
            table: 'student',
            note: 'Registered learners',
            route: '/students',
          ),
          DashboardMetric.table(
            icon: Icons.badge_outlined,
            label: 'Staff',
            table: 'staff',
            note: 'Staff profiles',
            route: '/users/staff',
          ),
          DashboardMetric.table(
            icon: Icons.class_outlined,
            label: 'Classes',
            table: 'class',
            note: 'Across all forms',
            route: '/academics/class-setup',
          ),
          DashboardMetric.table(
            icon: Icons.family_restroom_outlined,
            label: 'Guardians',
            table: 'guardian',
            note: 'Guardian records',
            route: '/users/guardians',
          ),
        ],
        queueTitle: 'Attention queue',
        queueNote: 'Regular review',
        queue: const [
          DashboardLink(
            'Student records',
            Icons.groups_outlined,
            '/students',
            detail: 'Review enrolment and guardian links',
          ),
          DashboardLink(
            'Academic setup',
            Icons.school_outlined,
            '/academics/years',
            detail: 'Check years, classes and subject configuration',
          ),
          DashboardLink(
            'Staff accounts',
            Icons.badge_outlined,
            '/users/staff',
            detail: 'Maintain active staff and role details',
          ),
        ],
        groups: const [
          DashboardGroup('Students', [
            DashboardLink('All Students', Icons.groups_outlined, '/students'),
            DashboardLink(
              'Register Student',
              Icons.person_add_alt,
              '/students/new',
            ),
          ]),
          DashboardGroup('Guardians', [
            DashboardLink(
              'Guardians',
              Icons.family_restroom_outlined,
              '/users/guardians',
            ),
          ]),
          DashboardGroup('Staff', [
            DashboardLink('Staff List', Icons.badge_outlined, '/users/staff'),
            DashboardLink(
              'Add Staff',
              Icons.person_add_alt_1_outlined,
              '/users/staff/new',
            ),
          ]),
          DashboardGroup('Academic structure', [
            DashboardLink(
              'Academic Years',
              Icons.calendar_today_outlined,
              '/academics/years',
            ),
            DashboardLink(
              'Subjects',
              Icons.menu_book_outlined,
              '/academics/subjects',
            ),
            DashboardLink(
              'Class Setup',
              Icons.account_tree_outlined,
              '/academics/class-setup',
            ),
          ]),
          DashboardGroup('Finance', [
            DashboardLink(
              'Payments',
              Icons.payments_outlined,
              '/finance/payments',
            ),
            DashboardLink(
              'Fee Structures',
              Icons.receipt_long_outlined,
              '/finance/fees',
            ),
            DashboardLink(
              'Payment Configuration',
              Icons.tune_outlined,
              '/finance/payment-configuration',
            ),
          ]),
          DashboardGroup('Communications & reports', [
            DashboardLink(
              'Calendar',
              Icons.calendar_month_outlined,
              '/calendar',
            ),
            DashboardLink('Reports', Icons.analytics_outlined, '/reports'),
          ]),
        ],
      ),
    );
  }
}
