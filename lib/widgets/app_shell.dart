import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_tokens.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';

// Nav item model

class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

// Sidebar collapse widths

const double _kSidebarExpanded = 220;
const double _kSidebarCollapsed = 64;

// AppShell

class AppShell extends ConsumerWidget {
  final List<NavItem> navItems;
  final Widget body;
  final String homeRoute;
  final PreferredSizeWidget? appBar;

  const AppShell({
    super.key,
    required this.navItems,
    required this.body,
    required this.homeRoute,
    this.appBar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    return wide
        ? _WideLayout(
            navItems: navItems,
            body: body,
            homeRoute: homeRoute,
            appBar: appBar,
          )
        : _NarrowLayout(
            navItems: navItems,
            body: body,
            homeRoute: homeRoute,
            appBar: appBar,
          );
  }
}

// Wide layout (sidebar)

class _WideLayout extends StatefulWidget {
  final List<NavItem> navItems;
  final Widget body;
  final String homeRoute;
  final PreferredSizeWidget? appBar;

  const _WideLayout({
    required this.navItems,
    required this.body,
    required this.homeRoute,
    this.appBar,
  });

  @override
  State<_WideLayout> createState() => _WideLayoutState();
}

class _WideLayoutState extends State<_WideLayout>
    with SingleTickerProviderStateMixin {
  bool _collapsed = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _widthAnim = Tween<double>(
      begin: _kSidebarExpanded,
      end: _kSidebarCollapsed,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _collapsed = !_collapsed);
    _collapsed ? _animCtrl.forward() : _animCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Animated sidebar
          AnimatedBuilder(
            animation: _widthAnim,
            builder: (context, child) =>
                SizedBox(width: _widthAnim.value, child: child),
            child: _Sidebar(
              navItems: widget.navItems,
              homeRoute: widget.homeRoute,
              collapsed: _collapsed,
              onToggle: _toggle,
            ),
          ),
          // Content
          Expanded(
            child: Column(
              children: [
                if (widget.appBar != null)
                  Material(
                    color: AppColors.background,
                    elevation: 0,
                    child: widget.appBar!,
                  ),
                Expanded(child: widget.body),
                const _WebFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Narrow layout (bottom nav)

class _NarrowLayout extends ConsumerWidget {
  final List<NavItem> navItems;
  final Widget body;
  final String homeRoute;
  final PreferredSizeWidget? appBar;

  const _NarrowLayout({
    required this.navItems,
    required this.body,
    required this.homeRoute,
    this.appBar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar ?? _defaultAppBar(context, ref, homeRoute),
      drawer: _SideDrawer(navItems: navItems, homeRoute: homeRoute),
      body: body,
      bottomNavigationBar: _BottomNav(navItems: navItems, currentRoute: loc),
    );
  }

  PreferredSizeWidget _defaultAppBar(
    BuildContext ctx,
    WidgetRef ref,
    String home,
  ) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: _Logo(),
      actions: [
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Home',
          onPressed: () => ctx.go(home),
        ),
        IconButton(
          icon: const Icon(Icons.logout_outlined),
          tooltip: 'Sign out',
          onPressed: () => ref.read(authProvider.notifier).signOut(),
        ),
      ],
    );
  }
}

// Sidebar

class _Sidebar extends ConsumerWidget {
  final List<NavItem> navItems;
  final String homeRoute;
  final bool collapsed;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.navItems,
    required this.homeRoute,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final loc = GoRouterState.of(context).matchedLocation;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.sidebar,
        boxShadow: AppShadows.sidebar,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Logo + collapse toggle
            Padding(
              padding: EdgeInsets.fromLTRB(
                collapsed ? Sp.sm : Sp.xl,
                Sp.lg,
                collapsed ? Sp.sm : Sp.md,
                Sp.md,
              ),
              child: Row(
                children: [
                  if (!collapsed) ...[
                    _LogoIcon(size: 32),
                    const SizedBox(width: Sp.sm),
                    const Expanded(
                      child: Text(
                        'Mai Halima',
                        style: TextStyle(
                          fontFamily: AppText.fontHeading,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  // Toggle button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: Radii.smBr,
                      onTap: onToggle,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          collapsed ? Icons.chevron_right : Icons.chevron_left,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // User chip (hidden when collapsed)
            if (!collapsed && user != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                child: Container(
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
                        radius: 14,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: Text(
                          user.username.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
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
              ),

            // Collapsed: avatar only
            if (collapsed && user != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sp.sm,
                  vertical: Sp.sm,
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    user.username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: Sp.sm),

            // Home item
            _SidebarItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              isActive: loc == homeRoute,
              onTap: () => context.go(homeRoute),
              collapsed: collapsed,
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? Sp.sm : Sp.xl,
                vertical: Sp.xs,
              ),
              child: const Divider(color: Colors.white24, height: 1),
            ),

            // Nav items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: navItems.map((item) {
                  final active = loc.startsWith(item.route);
                  return _SidebarItem(
                    icon: item.icon,
                    activeIcon: item.activeIcon,
                    label: item.label,
                    isActive: active,
                    onTap: () => context.go(item.route),
                    collapsed: collapsed,
                  );
                }).toList(),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? Sp.sm : Sp.xl,
                vertical: Sp.xs,
              ),
              child: const Divider(color: Colors.white24, height: 1),
            ),

            // Logout
            _SidebarItem(
              icon: Icons.logout_outlined,
              activeIcon: Icons.logout,
              label: 'Sign Out',
              isActive: false,
              onTap: () => ref.read(authProvider.notifier).signOut(),
              danger: true,
              collapsed: collapsed,
            ),
            const SizedBox(height: Sp.lg),
          ],
        ),
      ),
    );
  }

  String _roleFriendly(String r) => r
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (w) =>
            w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');
}

// Sidebar item

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool danger;
  final bool collapsed;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.collapsed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = danger
        ? Colors.redAccent.shade100
        : isActive
        ? Colors.white
        : Colors.white.withValues(alpha: 0.65);

    // Collapsed: icon-only with tooltip
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.xs, vertical: 2),
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: Material(
            color: isActive
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: Radii.smBr,
            child: InkWell(
              onTap: onTap,
              borderRadius: Radii.smBr,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: Sp.sm + 2,
                  horizontal: Sp.sm,
                ),
                child: Center(
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 20,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded: icon + label
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 2),
      child: Material(
        color: isActive
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: Radii.mdBr,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.mdBr,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.md,
              vertical: Sp.sm + 2,
            ),
            child: Row(
              children: [
                Icon(isActive ? activeIcon : icon, size: 20, color: iconColor),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppText.fontBody,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: iconColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Side drawer (narrow fallback)

class _SideDrawer extends ConsumerWidget {
  final List<NavItem> navItems;
  final String homeRoute;

  const _SideDrawer({required this.navItems, required this.homeRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.primary,
      child: _Sidebar(
        navItems: navItems,
        homeRoute: homeRoute,
        collapsed: false,
        onToggle: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// Bottom nav (narrow)

class _BottomNav extends StatelessWidget {
  final List<NavItem> navItems;
  final String currentRoute;

  const _BottomNav({required this.navItems, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final visible = navItems.take(4).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x144F5FEE),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: visible.map((item) {
              final active = currentRoute.startsWith(item.route);
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(item.route),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        size: 22,
                        color: active
                            ? AppColors.primary
                            : AppColors.textDisabled,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: AppText.fontBody,
                          fontSize: 9,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active
                              ? AppColors.primary
                              : AppColors.textDisabled,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// Web footer

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
          _LogoIcon(size: 18),
          const SizedBox(width: Sp.sm),
          const Text(
            'Mai Halima School Management',
            style: TextStyle(
              fontFamily: AppText.fontHeading,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '© ${DateTime.now().year} Mai Halima School - All rights reserved',
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

// Logo variants

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoIcon(size: 28),
        const SizedBox(width: Sp.sm),
        const Text(
          'Mai Halima',
          style: TextStyle(
            fontFamily: AppText.fontHeading,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

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
          'M',
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
