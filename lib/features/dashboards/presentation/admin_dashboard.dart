import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/notched_card.dart';
import '../../../widgets/stat_badge_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/app_card.dart';
import '../../../core/navigation/nav_items.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return AppShell(
      navItems: getNavItemsForRole(user?.roleName ?? 'GUEST'),
      homeRoute: '/admin/home',
      body: _Body(username: user?.username ?? ''),
    );
  }
}

class _Body extends StatelessWidget {
  final String username;
  const _Body({required this.username});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome hero
          NotchedCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${_first(username)}',
                        style: const TextStyle(
                          fontFamily: AppText.fontHeading,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: Sp.xs),
                      Text(
                        'Welcome to the System Admin dashboard.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(Sp.lg),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: Radii.lgBr,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.xl),

          // Stat cards
          SectionHeader('Overview', icon: Icons.bar_chart),
          _StatGrid(context),
          const SizedBox(height: Sp.xs),

          // Quick actions
          SectionHeader('Quick Actions', icon: Icons.flash_on),
          _ActionGrid(context),
          const SizedBox(height: Sp.xs),

          // System
          SectionHeader('System', icon: Icons.settings),
          _SystemGrid(context),
        ],
      ),
    );
  }

  Widget _StatGrid(BuildContext ctx) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Sp.md,
      crossAxisSpacing: Sp.md,
      childAspectRatio: 1.5,
      children: [
        StatBadgeCard(
          label: 'Students',
          value: '-',
          icon: Icons.school,
          iconColor: AppColors.statBlue,
          onTap: () => ctx.go('/students'),
        ),
        StatBadgeCard(
          label: 'Staff',
          value: '-',
          icon: Icons.badge,
          iconColor: AppColors.statOrange,
          onTap: () => ctx.go('/users/staff'),
        ),
        StatBadgeCard(
          label: 'Guardians',
          value: '-',
          icon: Icons.family_restroom,
          iconColor: AppColors.statGreen,
          onTap: () => ctx.go('/users/guardians'),
        ),
        StatBadgeCard(
          label: 'System Users',
          value: '-',
          icon: Icons.manage_accounts,
          iconColor: AppColors.statRed,
          onTap: () => ctx.go('/admin/users'),
        ),
      ],
    );
  }

  Widget _ActionGrid(BuildContext ctx) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Sp.md,
      crossAxisSpacing: Sp.md,
      childAspectRatio: 2.2,
      children: [
        _Tile(
          'Enrol Student',
          Icons.person_add,
          AppColors.statBlue,
          () => ctx.go('/students/new'),
        ),
        _Tile(
          'Create User',
          Icons.person_add_alt,
          AppColors.statOrange,
          () => ctx.go('/admin/users/create'),
        ),
        _Tile(
          'Add Academic Year',
          Icons.calendar_today,
          AppColors.statGreen,
          () => ctx.go('/academics/years'),
        ),
        _Tile(
          'Fee Structures',
          Icons.price_change,
          AppColors.statRed,
          () => ctx.go('/finance/fees'),
        ),
      ],
    );
  }

  Widget _SystemGrid(BuildContext ctx) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Sp.md,
      crossAxisSpacing: Sp.md,
      childAspectRatio: 2.2,
      children: [
        _Tile(
          'Audit Log',
          Icons.history,
          AppColors.primary,
          () => ctx.go('/admin/audit-log'),
        ),
        _Tile(
          'Notifications',
          Icons.notifications,
          AppColors.statOrange,
          () => ctx.go('/notifications'),
        ),
        _Tile(
          'Assignments',
          Icons.assignment_ind,
          AppColors.statGreen,
          () => ctx.go('/academics/assignments'),
        ),
        _Tile(
          'Reports',
          Icons.analytics,
          AppColors.statRed,
          () => ctx.go('/reports'),
        ),
      ],
    );
  }

  String _first(String u) {
    final p = u.split(RegExp(r'[@._\s]')).first;
    return p.isEmpty ? 'there' : p[0].toUpperCase() + p.substring(1);
  }
}

// Reusable action tile

class _Tile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _Tile(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Sp.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: Radii.smBr,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppText.fontBody,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
