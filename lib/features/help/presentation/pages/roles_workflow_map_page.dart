import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router.dart' show isRouteAllowedForRole;
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/guidance_content.dart';

/// Super User guidance: the six roles, their boundaries and the end-to-end
/// workflows. Static content; every "Open" link is checked against the
/// signed-in role's route access.
class RolesWorkflowMapPage extends ConsumerWidget {
  const RolesWorkflowMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final workspaceRole = ref.watch(activeWorkspaceRoleProvider);
    final role = workspaceRole.isEmpty ? user?.roleName ?? '' : workspaceRole;

    return UiPage(
      children: [
        const PageHead(
          kicker: 'System',
          title: 'Roles & Workflow Map',
          subtitle:
              'The optimised flows for every role, each opening its workspace.',
        ),
        const SizedBox(height: 16),
        const _FlowBanner(),
        const SizedBox(height: 16),
        AdaptiveGrid(
          columns: 3,
          mediumColumns: 2,
          children: [
            for (var i = 0; i < roleCards.length; i++)
              _RoleCard(index: i + 1, info: roleCards[i]),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'End-to-end workflows',
          trailing: const PanelNote('One workspace per job'),
          child: Column(
            children: [
              for (final flow in workflows)
                _WorkflowRow(
                  flow: flow,
                  canOpen:
                      flow.route != null &&
                      isRouteAllowedForRole(role, flow.route!),
                  onOpen: () => context.go(flow.route!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlowBanner extends StatelessWidget {
  const _FlowBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ONE WORKSPACE PER JOB',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Color(0xFF8FB8E8),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Operational tasks live in task workspaces',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'History, reports, permissions and audit trails stay reachable '
            'through tabs, side panels and contextual links.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB9D7F8),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final int index;
  final RoleCardInfo info;
  const _RoleCard({required this.index, required this.info});

  @override
  Widget build(BuildContext context) {
    return UiCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.responsibilities,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info.boundary,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Quick start: ',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      TextSpan(text: info.quickStart),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowRow extends StatelessWidget {
  final WorkflowInfo flow;
  final bool canOpen;
  final VoidCallback onOpen;
  const _WorkflowRow({
    required this.flow,
    required this.canOpen,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      flow.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    StatusPill(flow.role, tone: StatusTone.info),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  flow.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${flow.workspace}  ·  ${flow.shape}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (canOpen) ...[
            const SizedBox(width: 12),
            UiButton.secondary('Open', onPressed: onOpen),
          ],
        ],
      ),
    );
  }
}
