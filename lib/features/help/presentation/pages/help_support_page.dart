import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router.dart' show isRouteAllowedForRole;
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../settings/domain/school_settings.dart';
import '../../../settings/presentation/settings_providers.dart';
import '../../data/external_launcher.dart';
import '../../data/guidance_content.dart';
import '../widgets/copy_button.dart';

/// Role-aware guidance plus the school's contact details. Nothing on this page
/// sends data anywhere.
class HelpSupportPage extends ConsumerWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final workspaceRole = ref.watch(activeWorkspaceRoleProvider);
    final role = schoolRole(
      workspaceRole.isEmpty ? user?.roleName ?? '' : workspaceRole,
    );
    final items = helpByRole[role] ?? const <HelpItem>[];
    final settings = ref
        .watch(schoolSettingsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final branding = ref
        .watch(schoolBrandingProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);

    return UiPage(
      children: [
        const PageHead(
          kicker: 'System',
          title: 'Help & Support',
          subtitle: 'Role-aware guidance and common workflow help.',
        ),
        const SizedBox(height: 16),
        SplitLayout(
          mainFlex: 1,
          sideFlex: 1,
          main: Panel(
            title: 'Popular guidance',
            trailing: PanelNote('${schoolRoleLabel(role)} workspace'),
            child: items.isEmpty
                ? const UiEmptyState(
                    icon: Icons.help_outline_rounded,
                    title: 'No guidance for this role yet',
                  )
                : QueueList(
                    items: [
                      for (final item in items)
                        QueueItem(
                          icon: Icons.menu_book_outlined,
                          title: item.title,
                          subtitle: item.text,
                          onTap: isRouteAllowedForRole(role, item.route)
                              ? () => context.go(item.route)
                              : null,
                        ),
                    ],
                  ),
          ),
          side: _ContactPanel(
            schoolName: settings?.schoolName ?? branding?.schoolName,
            settings: settings,
          ),
        ),
      ],
    );
  }
}

class _ContactPanel extends ConsumerWidget {
  final String? schoolName;
  final SchoolSettings? settings;
  const _ContactPanel({required this.schoolName, required this.settings});

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Uri? uri,
    String failure,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    if (uri != null) {
      try {
        opened = await ref.read(uriLauncherProvider)(uri);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = _clean(settings?.phoneNumber);
    final email = _clean(settings?.emailAddress);
    final address = _clean(settings?.physicalAddress);
    final website = _clean(settings?.website);
    final usingDefaults = phone == null || email == null || address == null;

    final lines = <(String, String)>[
      ('Phone', phone ?? AppStrings.contactPhone),
      ('Email', email ?? AppStrings.contactEmail),
      ('Address', address ?? AppStrings.contactAddress),
      if (website != null) ('Website', website),
    ];

    return Panel(
      title: 'Contact support',
      trailing: const PanelNote('During school hours'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_clean(schoolName) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                schoolName!.trim(),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          for (final line in lines)
            DetailLine(
              line.$1,
              line.$2,
              trailing: line.$1 == 'Email' || line.$1 == 'Phone'
                  ? CopyButton(text: line.$2, tooltip: 'Copy ${line.$1}')
                  : null,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              UiButton.secondary(
                'Email support',
                icon: Icons.mail_outline,
                onPressed: () => _open(
                  context,
                  ref,
                  supportMailtoUri(
                    email ?? AppStrings.contactEmail,
                    subject: 'Support request',
                  ),
                  'Could not open an email app. Copy the address instead.',
                ),
              ),
              UiButton.secondary(
                'Call school',
                icon: Icons.call_outlined,
                onPressed: () => _open(
                  context,
                  ref,
                  supportTelUri(phone ?? AppStrings.contactPhone),
                  'Could not start a call. Copy the number instead.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (usingDefaults)
            const UiNotice(
              'Some contact details are not set in School Settings yet, so '
              'default details are shown.',
              tone: StatusTone.info,
              icon: Icons.info_outline_rounded,
            ),
        ],
      ),
    );
  }
}
