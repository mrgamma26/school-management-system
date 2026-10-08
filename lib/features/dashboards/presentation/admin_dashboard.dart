import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/notched_card.dart';
import '../../../widgets/stat_badge_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/app_card.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../../core/database/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return AppShell(
      homeRoute: '/admin/home',
      body: _Body(username: user?.username ?? ''),
    );
  }
}

class _Body extends ConsumerWidget {
  final String username;
  const _Body({required this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
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
              SectionHeader(
                'Overview',
                icon: Icons.bar_chart,
                actionLabel: 'Refresh',
                onAction: () => ref.invalidate(adminOverviewCountProvider),
              ),
              _statGrid(context, ref),
              const SizedBox(height: Sp.lg),

              // Quick actions
              SectionHeader('Quick Actions', icon: Icons.flash_on),
              _actionGrid(context),
              const SizedBox(height: Sp.lg),

              // System
              SectionHeader('System', icon: Icons.settings),
              _systemGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statGrid(BuildContext ctx, WidgetRef ref) {
    return _dashboardGrid(
      maxColumns: 4,
      itemHeight: 150,
      children: [
        _countCard(
          ref: ref,
          table: 'student',
          label: 'Students',
          icon: Icons.school,
          iconColor: AppColors.statBlue,
          onTap: () => ctx.go('/students'),
        ),
        _countCard(
          ref: ref,
          table: 'staff',
          label: 'Staff',
          icon: Icons.badge,
          iconColor: AppColors.statOrange,
          onTap: () => ctx.go('/users/staff'),
        ),
        _countCard(
          ref: ref,
          table: 'guardian',
          label: 'Guardians',
          icon: Icons.family_restroom,
          iconColor: AppColors.statGreen,
          onTap: () => ctx.go('/users/guardians'),
        ),
        _countCard(
          ref: ref,
          table: 'systemuser',
          label: 'System Users',
          icon: Icons.manage_accounts,
          iconColor: AppColors.statRed,
          onTap: () => ctx.go('/admin/users'),
        ),
      ],
    );
  }

  Widget _countCard({
    required WidgetRef ref,
    required String table,
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final count = ref.watch(adminOverviewCountProvider(table));
    return Tooltip(
      message: count.hasError
          ? 'Count unavailable. Refresh to try again.'
          : label,
      child: StatBadgeCard(
        label: label,
        value: count.when(
          data: (value) => '$value',
          loading: () => '…',
          error: (_, _) => '!',
        ),
        icon: icon,
        iconColor: iconColor,
        onTap: onTap,
      ),
    );
  }

  Widget _actionGrid(BuildContext ctx) {
    return _dashboardGrid(
      maxColumns: 3,
      itemHeight: 76,
      children: [
        _Tile(
          'Add Student',
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
          () => ctx.push('/academics/years/new'),
        ),
      ],
    );
  }

  Widget _systemGrid(BuildContext ctx) {
    return _dashboardGrid(
      maxColumns: 3,
      itemHeight: 76,
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
          'Payment Configuration',
          Icons.tune,
          AppColors.statGreen,
          () => ctx.go('/finance/payment-configuration'),
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

  Widget _dashboardGrid({
    required int maxColumns,
    required double itemHeight,
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? maxColumns
            : width >= 560 || (maxColumns == 4 && width >= 360)
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: itemHeight,
            mainAxisSpacing: Sp.md,
            crossAxisSpacing: Sp.md,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
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
          const SizedBox(width: Sp.xs),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
