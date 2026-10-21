import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_strings.dart';
import '../core/navigation/role_menus.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';
import '../features/settings/presentation/settings_providers.dart';
import '../theme/app_tokens.dart';

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

/// Role workspace frame: navy sidebar + top bar, matching the approved design.
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
    final activeRole = ref.watch(activeWorkspaceRoleProvider);
    final role = activeRole.isEmpty ? user?.roleName ?? '' : activeRole;
    final permissions = ref
        .watch(permissionsProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <String>{});
    final nodes = menuForRole(role, permissions);

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < Breakpoints.mobile;
        final content = Column(
          children: [
            appBar ?? _TopBar(homeRoute: homeRoute, phone: phone),
            Expanded(child: body),
          ],
        );
        final panel = _NavigationPanel(
          nodes: nodes,
          homeRoute: homeRoute,
          closeOnNavigate: phone,
        );
        return Scaffold(
          backgroundColor: AppColors.background,
          drawer: phone
              ? Drawer(
                  backgroundColor: AppColors.navy,
                  width: 280,
                  child: panel,
                )
              : null,
          body: phone
              ? content
              : Row(
                  children: [
                    SizedBox(width: AppSizes.sidebarWidth, child: panel),
                    Expanded(child: content),
                  ],
                ),
        );
      },
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final String homeRoute;
  final bool phone;
  const _TopBar({required this.homeRoute, required this.phone});

  static String _titleFor(String location) {
    final parts = location
        .split('?')
        .first
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Overview';
    final last = parts.last == 'home' && parts.length > 1
        ? 'Overview'
        : parts.last;
    return last
        .replaceAll(RegExp(r'[-_]'), ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final school = ref
        .watch(schoolBrandingProvider)
        .maybeWhen(data: (v) => v.schoolName, orElse: () => AppStrings.appName);

    return Container(
      height: AppSizes.topbarHeight,
      padding: EdgeInsets.symmetric(horizontal: phone ? 8 : 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (phone)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (!phone)
                    TextSpan(
                      text: '$school / ',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  TextSpan(
                    text: _titleFor(location),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _TopIconButton(
            icon: Icons.home_outlined,
            tooltip: 'Home',
            onTap: () => context.go(homeRoute),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppColors.primaryDark),
        ),
      ),
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _NavigationPanel extends ConsumerWidget {
  final List<MenuNode> nodes;
  final String homeRoute;
  final bool closeOnNavigate;

  const _NavigationPanel({
    required this.nodes,
    required this.homeRoute,
    required this.closeOnNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final activeRole = ref.watch(activeWorkspaceRoleProvider);
    final roleKey = activeRole.isEmpty ? (user?.roleName ?? '') : activeRole;
    final location = GoRouterState.of(context).matchedLocation;
    final branding = ref
        .watch(schoolBrandingProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);

    void navigate(String route) {
      if (closeOnNavigate) Navigator.of(context).pop();
      context.go(route);
    }

    return Material(
      color: AppColors.navy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
              child: Row(
                children: [
                  const _LogoIcon(size: 42),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branding?.schoolName ?? AppStrings.appName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_roleFriendly(roleKey).toUpperCase()} WORKSPACE',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Color(0xFF8FB8E8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _NavLink(
                    icon: Icons.dashboard_outlined,
                    label: 'Overview',
                    route: homeRoute,
                    location: location,
                    exact: true,
                    onTap: () => navigate(homeRoute),
                  ),
                  ...nodes.map(
                    (node) => _node(context, node, location, navigate),
                  ),
                ],
              ),
            ),
            if (user?.hasWorkspaceSwitcher == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Theme(
                  data: Theme.of(context).copyWith(canvasColor: AppColors.navy),
                  child: DropdownButtonFormField<String>(
                    initialValue: activeRole,
                    dropdownColor: AppColors.navy,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Switch role',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: const TextStyle(color: Color(0xFFB9D7F8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TEACHER',
                        child: Text('Teacher'),
                      ),
                      DropdownMenuItem(
                        value: 'HEAD_TEACHER',
                        child: Text('Head Teacher'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      ref
                          .read(activeWorkspaceRoleProvider.notifier)
                          .switchTo(value);
                      navigate(
                        value == 'TEACHER'
                            ? '/teacher/home'
                            : '/headteacher/home',
                      );
                    },
                  ),
                ),
              ),
            if (user != null)
              // Flat user card: taps through to the profile, no accent stripe.
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: 'My profile',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          hoverColor: Colors.white10,
                          onTap: () => navigate('/profile'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: AppColors.primaryLight,
                                  child: Text(
                                    user.username.isEmpty
                                        ? '?'
                                        : user.username
                                              .trim()
                                              .split(RegExp(r'\s+'))
                                              .take(2)
                                              .map((p) => p.isEmpty ? '' : p[0])
                                              .join()
                                              .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        _roleFriendly(roleKey),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFB9D7F8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      icon: const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          ref.read(authProvider.notifier).signOut(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _node(
    BuildContext context,
    MenuNode node,
    String location,
    void Function(String) navigate,
  ) {
    if (!node.isGroup) {
      return _NavLink(
        icon: node.icon,
        label: node.label,
        route: node.route!,
        location: location,
        onTap: () => navigate(node.route!),
      );
    }
    final active = node.children.any(
      (child) =>
          child.route != null &&
          (location == child.route || location.startsWith('${child.route}/')),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.white10,
        highlightColor: Colors.white10,
      ),
      child: ExpansionTile(
        initiallyExpanded: active,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.only(left: 12),
        iconColor: Colors.white,
        collapsedIconColor: AppColors.sidebarInactive,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: _IconChip(icon: node.icon, active: false),
        title: Text(
          node.label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.sidebarInactive,
          ),
        ),
        children: node.children
            .map((child) => _node(context, child, location, navigate))
            .toList(),
      ),
    );
  }

  static String _roleFriendly(String role) => role
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map(
        (word) =>
            word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _IconChip({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active
            ? AppColors.primarySurface
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 16,
        color: active ? AppColors.primaryDark : Colors.white,
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String location;
  final bool exact;
  final VoidCallback onTap;

  const _NavLink({
    required this.icon,
    required this.label,
    required this.route,
    required this.location,
    required this.onTap,
    this.exact = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = exact
        ? location == route
        : (location == route || location.startsWith('$route/'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          hoverColor: Colors.white10,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                _IconChip(icon: icon, active: active),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? AppColors.primaryDark
                          : AppColors.sidebarInactive,
                    ),
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

class _LogoIcon extends ConsumerWidget {
  final double size;
  const _LogoIcon({this.size = 32});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(schoolSettingsRepositoryProvider);
    final branding = ref
        .watch(schoolBrandingProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final url = repository.publicLogoUrl(branding?.logoPath);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url != null
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _initials(branding?.schoolName),
              ),
            )
          : _initials(branding?.schoolName),
    );
  }

  Widget _initials(String? name) {
    final words = (name ?? AppStrings.appName)
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final text = words.isEmpty
        ? AppStrings.appInitial
        : words.take(2).map((w) => w[0]).join();
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: size * .38,
        fontWeight: FontWeight.w900,
        color: AppColors.primaryDark,
      ),
    );
  }
}
