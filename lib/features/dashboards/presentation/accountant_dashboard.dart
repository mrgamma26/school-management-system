import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../widgets/app_shell.dart';
import '../../../core/navigation/nav_items.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import 'dashboard_scaffold.dart';

class AccountantDashboard extends ConsumerWidget {
  const AccountantDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return AppShell(
      navItems: getNavItemsForRole(user?.roleName ?? 'GUEST'),
      homeRoute: '/accountant/home',
      body: DashboardBody(
        subtitle: 'Manage school finances, fee structures and payment records',
        roleIcon: Icons.account_balance,
        roleColor: AppColors.roleAccountant,
        children: [
          DashGrid(
            sectionTitle: 'Finance',
            sectionIcon: Icons.account_balance_wallet,
            tiles: [
              _T(
                'All Payments',
                Icons.payments,
                AppColors.success,
                () => context.go('/finance/payments'),
              ),
              _T(
                'Fee Structures',
                Icons.price_change,
                AppColors.warning,
                () => context.go('/finance/fees'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Students',
            sectionIcon: Icons.people_outline,
            tiles: [
              _T(
                'Student Accounts',
                Icons.account_box,
                AppColors.roleAdmin,
                () => context.go('/students'),
              ),
              _T(
                'Record Payment',
                Icons.add_card,
                AppColors.roleAccountant,
                () => context.go('/students'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'Reports & Calendar',
            sectionIcon: Icons.bar_chart,
            tiles: [
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
