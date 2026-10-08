import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../widgets/app_shell.dart';
import 'dashboard_scaffold.dart';

class GuardianDashboard extends ConsumerWidget {
  const GuardianDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
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
                'Report Cards',
                Icons.assessment,
                AppColors.roleAdmin,
                () => context.go('/guardian/report-card'),
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
                  InfoRow(
                    'Phone',
                    AppStrings.contactPhone,
                    icon: Icons.phone_outlined,
                  ),
                  InfoRow(
                    'Email',
                    AppStrings.contactEmail,
                    icon: Icons.email_outlined,
                  ),
                  InfoRow(
                    'Address',
                    AppStrings.contactAddress,
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
