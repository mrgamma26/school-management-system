import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/constants/app_strings.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

/// Body-only content for a role dashboard - no Scaffold wrapping.
/// Use this inside [AppShell] to avoid nested Scaffolds.
class DashboardBody extends ConsumerWidget {
  final String subtitle;
  final IconData roleIcon;
  final Color roleColor;
  final List<Widget> children;

  const DashboardBody({
    super.key,
    required this.subtitle,
    required this.roleIcon,
    required this.roleColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _WelcomeBanner(
          name: user?.username ?? '',
          subtitle: subtitle,
          roleIcon: roleIcon,
          roleColor: roleColor,
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

/// Shared scaffold wrapping every role dashboard.
/// Provides a consistent AppBar, welcome banner, and sign-out action.
/// NOTE: Only use this when NOT wrapping in AppShell (which has its own Scaffold).
class DashboardScaffold extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData roleIcon;
  final Color roleColor;
  final List<Widget> children;

  const DashboardScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.roleIcon,
    required this.roleColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.school, size: 20, color: roleColor),
            ),
            const SizedBox(width: 10),
            Text(AppStrings.appName),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: RoleBadge(user.roleName),
            ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: DashboardBody(
        subtitle: subtitle,
        roleIcon: roleIcon,
        roleColor: roleColor,
        children: children,
      ),
    );
  }
}

// Welcome banner

class _WelcomeBanner extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData roleIcon;
  final Color roleColor;

  const _WelcomeBanner({
    required this.name,
    required this.subtitle,
    required this.roleIcon,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleColor, roleColor.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${_firstName(name)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(roleIcon, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  String _firstName(String username) {
    if (username.isEmpty) return 'there';
    final parts = username.split(RegExp(r'[@._\s]'));
    final first = parts.first;
    return first.isEmpty
        ? username
        : first[0].toUpperCase() + first.substring(1);
  }
}

// Grid section

class DashGrid extends StatelessWidget {
  final String sectionTitle;
  final IconData? sectionIcon;
  final List<TileData> tiles;
  final int maxColumns;

  const DashGrid({
    super.key,
    required this.sectionTitle,
    this.sectionIcon,
    required this.tiles,
    this.maxColumns = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(sectionTitle, icon: sectionIcon),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = maxColumns == 1
                ? 1
                : maxColumns == 3
                ? (constraints.maxWidth >= 760 ? 3 : 1)
                : (constraints.maxWidth >= 480 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tiles.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 132,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final t = tiles[index];
                return DashTile(
                  label: t.label,
                  icon: t.icon,
                  color: t.color,
                  onTap: t.onTap,
                  badge: t.badge,
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class TileData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  const TileData(this.label, this.icon, this.color, this.onTap, {this.badge});
}
