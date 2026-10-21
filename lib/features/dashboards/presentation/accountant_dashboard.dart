import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_shell.dart';
import 'dashboard_charts.dart';
import 'dashboard_scaffold.dart';

/// Screen 6 - Accountant dashboard.
class AccountantDashboard extends ConsumerWidget {
  const AccountantDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      homeRoute: '/accountant/home',
      body: RoleDashboard(
        kicker: '',
        title: 'Accountant Dashboard',
        subtitle: '',
        charts: accountantCharts(),
        quickStart: const [
          DashboardLink(
            'Student Accounts',
            Icons.account_balance_wallet_outlined,
            '/finance/accounts',
            detail: 'Find a student and record a payment',
          ),
          DashboardLink(
            'Overdue Accounts',
            Icons.warning_amber_rounded,
            '/finance/overdue',
            detail: 'Learners who still owe fees',
          ),
          DashboardLink(
            'Payments',
            Icons.payments_outlined,
            '/finance/payments',
            detail: 'Review posted receipts',
          ),
        ],
        queueRole: 'ACCOUNTANT',
        metrics: [
          DashboardMetric.table(
            icon: Icons.payments_outlined,
            label: 'Payments recorded',
            table: 'payment',
            note: 'Posted receipts',
            route: '/finance/payments',
          ),
          DashboardMetric.table(
            icon: Icons.receipt_long_outlined,
            label: 'Deposit slips',
            table: 'deposit_slips',
            note: 'Uploaded evidence',
          ),
          DashboardMetric.table(
            icon: Icons.price_change_outlined,
            label: 'Fee structures',
            table: 'feestructure',
            note: 'Charging structures',
            route: '/finance/fees',
          ),
          DashboardMetric.table(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Student accounts',
            table: 'student',
            note: 'Learners with accounts',
            route: '/students',
          ),
        ],
        queueTitle: 'Verification queue',
        queueNote: 'Finance work',
        queue: const [
          DashboardLink(
            'Student accounts',
            Icons.account_balance_wallet_outlined,
            '/students',
            detail: 'Review balances before recording a payment',
          ),
          DashboardLink(
            'Payment ledger',
            Icons.receipt_long_outlined,
            '/finance/payments',
            detail: 'Review posted receipts and reversals',
          ),
          DashboardLink(
            'Fee structures',
            Icons.price_change_outlined,
            '/finance/fees',
            detail: 'Maintain the current charging structure',
          ),
        ],
        groups: const [
          DashboardGroup('Finance', [
            DashboardLink('All Payments', Icons.payments_outlined, '/finance/payments'),
            DashboardLink(
              'Fee Structures',
              Icons.price_change_outlined,
              '/finance/fees',
            ),
          ]),
          DashboardGroup('Students', [
            DashboardLink(
              'Students & Accounts',
              Icons.account_box_outlined,
              '/students',
            ),
          ]),
          DashboardGroup('Reports & calendar', [
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
