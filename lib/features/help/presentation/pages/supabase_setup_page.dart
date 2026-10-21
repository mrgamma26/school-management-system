import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../data/guidance_content.dart';
import '../widgets/copy_button.dart';

/// Static developer guidance for testing and applying Supabase migrations.
///
/// This page never reads, shows or asks for any key, token, password or
/// project URL. Commands use placeholders such as `<development-project-ref>`.
class SupabaseSetupPage extends StatelessWidget {
  const SupabaseSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return UiPage(
      children: [
        const PageHead(
          kicker: 'System',
          title: 'Supabase Migration Setup',
          subtitle:
              'Secure developer-account setup for testing and applying database migrations.',
        ),
        const SizedBox(height: 16),
        const _Banner(),
        const SizedBox(height: 16),
        Panel(
          title: 'Account and project requirements',
          trailing: const PanelNote('Owner-approved access'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdaptiveGrid(
                columns: 3,
                mediumColumns: 2,
                children: [
                  for (final item in supabaseRequirements)
                    _RequirementTile(item: item),
                ],
              ),
              const _NeverResetWarning(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Migration workflow',
          trailing: const PanelNote('Reviewed and repeatable'),
          child: Column(
            children: [
              for (var i = 0; i < supabaseSteps.length; i++)
                _StepRow(number: i + 1, step: supabaseSteps[i]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Panel(
          title: 'Command strip',
          trailing: PanelNote('Run in order, on a development project'),
          child: _CommandStrip(),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

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
            'DEVELOPER INFRASTRUCTURE',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Color(0xFF8FB8E8),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Supabase account required for remote migrations',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Each collaborator signs in with their own account. Never share a '
            'personal access token, database password, service-role key or '
            'production credential in email, chat, Flutter configuration or '
            'Git.',
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

class _RequirementTile extends StatelessWidget {
  final SetupRequirement item;
  const _RequirementTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeverResetWarning extends StatelessWidget {
  const _NeverResetWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StatusTone.danger.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: StatusTone.danger.foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Never run on production: ',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const TextSpan(
                    text: supabaseNeverRunCommand,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' destroys the linked remote database. It is only '
                        'acceptable for an explicitly disposable development '
                        'project.',
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: StatusTone.danger.foreground,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final SetupStep step;
  const _StepRow({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.45,
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

class _CommandStrip extends StatelessWidget {
  const _CommandStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < supabaseCommandStrip.length; i++)
          Container(
            margin: EdgeInsets.only(
              bottom: i == supabaseCommandStrip.length - 1 ? 0 : 8,
            ),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8FB8E8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(
                      supabaseCommandStrip[i],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                CopyButton(
                  text: supabaseCommandStrip[i],
                  tooltip: 'Copy command ${i + 1}',
                  color: Colors.white,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
