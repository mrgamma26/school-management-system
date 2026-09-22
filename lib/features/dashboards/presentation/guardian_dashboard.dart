import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../widgets/app_shell.dart';
import '../../../core/navigation/nav_items.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import 'dashboard_scaffold.dart';

class GuardianDashboard extends ConsumerWidget {
  const GuardianDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return AppShell(
      navItems: getNavItemsForRole(user?.roleName ?? 'GUEST'),
      homeRoute: '/guardian/home',
      body: DashboardBody(
        subtitle: "Monitor your children's progress, fees and school updates",
        roleIcon: Icons.family_restroom,
        roleColor: AppColors.roleGuardian,
        children: [
          DashGrid(
            sectionTitle: 'My Children',
            sectionIcon: Icons.child_care,
            tiles: [
              _T(
                'Academic Progress',
                Icons.trending_up,
                AppColors.success,
                () => context.go('/guardian/progress'),
              ),
              _T(
                'Payment History',
                Icons.receipt_long,
                AppColors.roleAccountant,
                () => context.go('/guardian/payments'),
              ),
            ],
          ),
          DashGrid(
            sectionTitle: 'School Updates',
            sectionIcon: Icons.campaign,
            tiles: [
              _T(
                'Notifications',
                Icons.notifications,
                AppColors.roleHeadTeacher,
                () => context.go('/notifications'),
              ),
              _T(
                'School Calendar',
                Icons.calendar_month,
                AppColors.accent,
                () => context.go('/calendar'),
              ),
            ],
          ),
          // ── Contact info card ─────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader('School Contact', icon: Icons.phone),
                  const SizedBox(height: 8),
                  const InfoRow(
                    'Phone',
                    '+265 999 000 000',
                    icon: Icons.phone_outlined,
                  ),
                  const InfoRow(
                    'Email',
                    'info@maihalima.ac.mw',
                    icon: Icons.email_outlined,
                  ),
                  const InfoRow(
                    'Address',
                    'P.O Box 123, Malawi',
                    icon: Icons.location_on_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _T = TileData;
