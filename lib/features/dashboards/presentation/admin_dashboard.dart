import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/supabase_client.dart';
import '../../../widgets/app_shell.dart';
import 'dashboard_charts.dart';
import 'dashboard_scaffold.dart';

const _overviewColumns = <String, String>{
  'student': 'studentid',
  'staff': 'staffid',
  'guardian': 'guardianid',
  'systemuser': 'userid',
};

final adminOverviewCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, table) async {
      final column = _overviewColumns[table];
      if (column == null) throw ArgumentError.value(table, 'table');
      final result = await supabase
          .from(table)
          .select(column)
          .limit(0)
          .count(CountOption.exact);
      return result.count;
    });

/// Screen 2 - Super User dashboard.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  DashboardMetric _count(
    String table,
    String label,
    IconData icon,
    String route,
    String note,
  ) => DashboardMetric(
    icon: icon,
    label: label,
    note: note,
    route: route,
    watch: (ref) => ref.watch(adminOverviewCountProvider(table)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      homeRoute: '/admin/home',
      body: RoleDashboard(
        kicker: '',
        title: 'Super User Dashboard',
        subtitle: '',
        charts: superUserCharts(),
        quickStart: const [
          DashboardLink(
            'Create User',
            Icons.person_add_alt_1_outlined,
            '/admin/users/create',
            detail: 'Add an account and assign a role',
          ),
          DashboardLink(
            'Review Access',
            Icons.admin_panel_settings_outlined,
            '/admin/users',
            detail: 'Check account status and roles',
          ),
          DashboardLink(
            'Audit Log',
            Icons.history_rounded,
            '/admin/audit-log',
            detail: 'See who did what and when',
          ),
        ],
        queueRole: 'SUPER_USER',
        metrics: [
          _count(
            'student',
            'Students',
            Icons.school_outlined,
            '/students',
            'Registered learners',
          ),
          _count(
            'staff',
            'Staff',
            Icons.badge_outlined,
            '/users/staff',
            'Staff profiles',
          ),
          _count(
            'guardian',
            'Guardians',
            Icons.family_restroom_outlined,
            '/users/guardians',
            'Guardian records',
          ),
          _count(
            'systemuser',
            'System Users',
            Icons.manage_accounts_outlined,
            '/admin/users',
            'Accounts with sign-in access',
          ),
        ],
        queueTitle: 'System attention',
        queue: const [
          DashboardLink(
            'User accounts',
            Icons.manage_accounts_outlined,
            '/admin/users',
            detail: 'Review account status, roles and security actions',
          ),
          DashboardLink(
            'Audit log',
            Icons.history_rounded,
            '/admin/audit-log',
            detail: 'See privileged actions and who performed them',
          ),
          DashboardLink(
            'Payment configuration',
            Icons.tune_outlined,
            '/finance/payment-configuration',
            detail: 'Check the payment channels the school accepts',
          ),
        ],
        groups: const [
          DashboardGroup('Quick actions', [
            DashboardLink('Add Student', Icons.person_add_alt, '/students/new'),
            DashboardLink(
              'Create User',
              Icons.person_add_alt_1_outlined,
              '/admin/users/create',
            ),
            DashboardLink(
              'Add Academic Year',
              Icons.calendar_today_outlined,
              '/academics/years/new',
              push: true,
            ),
          ]),
          DashboardGroup('System', [
            DashboardLink('Reports', Icons.analytics_outlined, '/reports'),
          ]),
        ],
      ),
    );
  }
}
