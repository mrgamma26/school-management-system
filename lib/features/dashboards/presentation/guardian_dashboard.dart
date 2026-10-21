import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/ui_kit.dart';
import 'dashboard_charts.dart';
import 'dashboard_scaffold.dart';

/// Screen 7 - Guardian dashboard.
class GuardianDashboard extends ConsumerWidget {
  const GuardianDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      homeRoute: '/guardian/home',
      body: RoleDashboard(
        kicker: '',
        title: 'Guardian Dashboard',
        subtitle: '',
        charts: guardianCharts(),
        quickStart: const [
          DashboardLink(
            'My Children',
            Icons.family_restroom_outlined,
            '/guardian/child',
            detail: 'Results and fees for linked learners',
          ),
          DashboardLink(
            'Payment History',
            Icons.receipt_long_outlined,
            '/guardian/payments',
            detail: 'Receipts and balances',
          ),
          DashboardLink(
            'School Calendar',
            Icons.calendar_month_outlined,
            '/calendar',
            detail: 'Term dates and events',
          ),
        ],
        queueRole: 'GUARDIAN',
        metrics: [
          DashboardMetric.table(
            icon: Icons.child_care_outlined,
            label: 'Linked children',
            table: 'student',
            note: 'Active learners',
            route: '/guardian/child',
          ),
          DashboardMetric.table(
            icon: Icons.payments_outlined,
            label: 'Payments',
            table: 'payment',
            note: 'Receipts on record',
            route: '/guardian/payments',
          ),
          DashboardMetric.table(
            icon: Icons.calendar_month_outlined,
            label: 'Calendar events',
            table: 'calendarevent',
            note: 'Shared with you',
            route: '/calendar',
          ),
        ],
        queueTitle: 'Family snapshot',
        queueNote: 'Linked learners',
        queue: const [
          DashboardLink(
            'My children',
            Icons.family_restroom_outlined,
            '/guardian/child',
            detail: 'Results and fees for each linked child',
          ),
          DashboardLink(
            'Academic progress',
            Icons.insights_outlined,
            '/guardian/progress',
            detail: 'View published progress for linked learners',
          ),
          DashboardLink(
            'Report cards',
            Icons.assessment_outlined,
            '/guardian/report-card',
            detail: 'Open reports when account access allows',
          ),
          DashboardLink(
            'Payment history',
            Icons.payments_outlined,
            '/guardian/payments',
            detail: 'Review receipts and payment records',
          ),
        ],
        groups: const [
          DashboardGroup('My children', [
            DashboardLink(
              'Child Workspace',
              Icons.family_restroom_outlined,
              '/guardian/child',
            ),
            DashboardLink(
              'Academic Progress',
              Icons.trending_up_outlined,
              '/guardian/progress',
            ),
            DashboardLink(
              'Report Cards',
              Icons.assessment_outlined,
              '/guardian/report-card',
            ),
            DashboardLink(
              'Payment History',
              Icons.receipt_long_outlined,
              '/guardian/payments',
            ),
          ]),
          DashboardGroup('School updates', [
            DashboardLink(
              'School Calendar',
              Icons.calendar_month_outlined,
              '/calendar',
            ),
          ]),
        ],
        footer: const Panel(
          title: 'School contact',
          child: Column(
            children: [
              DetailLine('Phone', AppStrings.contactPhone),
              DetailLine('Email', AppStrings.contactEmail),
              DetailLine('Address', AppStrings.contactAddress),
            ],
          ),
        ),
      ),
    );
  }
}
