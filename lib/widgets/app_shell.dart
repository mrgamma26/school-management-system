import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_tokens.dart';
import '../core/constants/app_strings.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';
import '../core/navigation/role_menus.dart';

// ---------------------------------------------------------------------------
// NavItem — kept for backward-compat with nav_items.dart imports
// ---------------------------------------------------------------------------

class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final String? requiredPermission;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.requiredPermission,
  });
}

// ---------------------------------------------------------------------------
// AppShell — single Scaffold with a Drawer that is CLOSED by default
// ---------------------------------------------------------------------------

class AppShell extends ConsumerWidget {
  final Widget body;
  final String homeRoute;
  final PreferredSizeWidget? appBar;

  const AppShell({
    super.key,
    required this.body,
    required this.homeRoute,
    this.appBar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final granted = ref
        .watch(permissionsProvider)
        .maybeWhen(data: (d) => d, orElse: () => const <String>{});
    final nodes = menuForRole(user?.roleName ?? '', granted);
    final loc = GoRouterState.of(context).matchedLocation;
    final onHome = loc == homeRoute || loc.endsWith('/home');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar:
          appBar ??
          AppBar(
            toolbarHeight: 52,
            backgroundColor: AppColors.surface,
            elevation: 0,
            scrolledUnderElevation: 1,
            // Flutter auto-inserts the hamburger leading icon when drawer != null
            title: Row(
              children: [
                const _LogoIcon(size: 26),
                const SizedBox(width: Sp.sm),
                Flexible(
                  child: Text(
                    AppStrings.appName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppText.fontHeading,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (!onHome)
                IconButton(
                  icon: const Icon(Icons.home_outlined),
                  tooltip: 'Home',
                  onPressed: () => context.go(homeRoute),
                ),
              IconButton(
                icon: const Icon(Icons.logout_outlined),
                tooltip: 'Sign out',
                onPressed: () => ref.read(authProvider.notifier).signOut(),
              ),
            ],
          ),
      drawer: _MenuDrawer(nodes: nodes, homeRoute: homeRoute),
      body: body,
      bottomNavigationBar:
          MediaQuery.sizeOf(context).width >= Breakpoints.tablet
          ? const _WebFooter()
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Menu drawer — closed by default, groups collapsed until tapped
// ---------------------------------------------------------------------------

class _MenuDrawer extends ConsumerWidget {
  final List<MenuNode> nodes;
  final String homeRoute;

  const _MenuDrawer({required this.nodes, required this.homeRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final loc = GoRouterState.of(context).matchedLocation;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.xl),
              decoration: const BoxDecoration(gradient: AppGradients.sidebar),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _LogoIcon(size: 32),
                      const SizedBox(width: Sp.sm),
                      const Expanded(
                        child: Text(
                          AppStrings.appName,
                          style: TextStyle(
                            fontFamily: AppText.fontHeading,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (user != null) ...[
                    const SizedBox(height: Sp.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sp.md,
                        vertical: Sp.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: Radii.mdBr,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.25,
                            ),
                            child: Text(
                              user.username.isEmpty
                                  ? '?'
                                  : user.username[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: Sp.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  _roleFriendly(user.roleName),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Nav items ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Dashboard home link
                  _DrawerLink(
                    icon: Icons.home_outlined,
                    label: 'Dashboard',
                    route: homeRoute,
                    currentLoc: loc,
                    onNav: () {
                      Navigator.of(context).pop();
                      context.go(homeRoute);
                    },
                  ),
                  const Divider(height: 1, indent: Sp.lg, endIndent: Sp.lg),
                  ...nodes.map((n) => _buildNode(context, n, loc)),
                ],
              ),
            ),

            // ── Sign out ──────────────────────────────────────────
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_outlined, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).signOut();
              },
            ),
            const SizedBox(height: Sp.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(BuildContext context, MenuNode node, String loc) {
    if (!node.isGroup) {
      return _DrawerLink(
        icon: node.icon,
        label: node.label,
        route: node.route!,
        currentLoc: loc,
        onNav: () {
          Navigator.of(context).pop();
          context.go(node.route!);
        },
      );
    }

    // Group — check if any child is active so we can auto-expand
    final hasActive = _childActive(node, loc);

    return Theme(
      // Remove default ExpansionTile divider lines
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>(node.label),
        initiallyExpanded: hasActive,
        leading: Icon(node.icon, size: 20, color: AppColors.textSecondary),
        title: Text(
          node.label,
          style: const TextStyle(
            fontFamily: AppText.fontBody,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 0),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        children: node.children
            .map((c) => _buildNode(context, c, loc))
            .toList(),
      ),
    );
  }

  bool _childActive(MenuNode node, String loc) {
    for (final c in node.children) {
      if (c.isGroup) {
        if (_childActive(c, loc)) return true;
      } else {
        final r = c.route!;
        if (loc == r || loc.startsWith('$r/')) return true;
      }
    }
    return false;
  }

  static String _roleFriendly(String r) => r
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (w) =>
            w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');
}

// ---------------------------------------------------------------------------
// Single nav link inside the drawer
// ---------------------------------------------------------------------------

class _DrawerLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentLoc;
  final VoidCallback onNav;

  const _DrawerLink({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLoc,
    required this.onNav,
  });

  @override
  Widget build(BuildContext context) {
    final isStudentRegistration =
        currentLoc == '/students/new' ||
        currentLoc.startsWith('/students/new/');
    final active =
        (currentLoc == route || currentLoc.startsWith('$route/')) &&
        !(route == '/students' && isStudentRegistration);
    return ListTile(
      selected: active,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
      leading: Icon(
        icon,
        size: 20,
        color: active ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppText.fontBody,
          fontSize: 14,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Sp.xl,
        vertical: 0,
      ),
      onTap: onNav,
    );
  }
}

// ---------------------------------------------------------------------------
// Web footer (wide screens only)
// ---------------------------------------------------------------------------

class _WebFooter extends StatelessWidget {
  const _WebFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Sp.xxl, vertical: Sp.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          const _LogoIcon(size: 18),
          const SizedBox(width: Sp.sm),
          Text(
            AppStrings.appName,
            style: const TextStyle(
              fontFamily: AppText.fontHeading,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '© ${DateTime.now().year} ${AppStrings.appName} — ${AppStrings.copyright}',
            style: const TextStyle(
              fontFamily: AppText.fontBody,
              fontSize: 11,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo icon (reusable across shell and drawer header)
// ---------------------------------------------------------------------------

class _LogoIcon extends StatelessWidget {
  final double size;
  const _LogoIcon({this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.primaryHero,
        borderRadius: Radii.smBr,
        boxShadow: AppShadows.card,
      ),
      child: Center(
        child: Text(
          AppStrings.appInitial,
          style: TextStyle(
            fontFamily: AppText.fontHeading,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
