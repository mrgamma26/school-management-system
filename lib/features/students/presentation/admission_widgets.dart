// Presentational pieces of the student admission workspace: the numbered stage
// card and the live "what this submission creates" side panel. State and
// repository calls stay in StudentFormPage.

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/ui_kit.dart';
import '../../../widgets/ui_workspace.dart';
import '../domain/admission_progress.dart';

/// One numbered stage of the admission workspace. All stages stay on screen;
/// the card only shows whether the stage is done or optional.
class AdmissionStageCard extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final bool done;
  final bool optional;
  final Widget child;

  const AdmissionStageCard({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
    this.done = false,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: UiCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? AppColors.success : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : Text(
                          '$number',
                          style: const TextStyle(
                            fontSize: 12.5,
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
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (optional) ...[
                  const SizedBox(width: 8),
                  const StatusPill('Optional', tone: StatusTone.neutral),
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// What the typed-in values will create on submit, with live ticks.
class AdmissionSummaryPanel extends StatelessWidget {
  final AdmissionProgress progress;
  final String studentName;
  final String? studentFacts;
  final List<String> guardianLines;
  final String? classLine;
  final String? subjectsLine;

  const AdmissionSummaryPanel({
    super.key,
    required this.progress,
    required this.studentName,
    required this.studentFacts,
    required this.guardianLines,
    required this.classLine,
    required this.subjectsLine,
  });

  @override
  Widget build(BuildContext context) {
    final items = <WorkspaceBuildItem>[
      WorkspaceBuildItem(
        progress.studentReady
            ? 'Student record: $studentName'
            : 'Student record',
        progress.studentReady,
      ),
      WorkspaceBuildItem(
        guardianLines.isEmpty
            ? 'Guardian link'
            : guardianLines.length == 1
            ? 'Guardian link: ${guardianLines.single}'
            : '${guardianLines.length} guardian links',
        progress.guardianReady,
      ),
      WorkspaceBuildItem(
        classLine ?? 'Class placement (optional)',
        progress.classChosen,
      ),
      if (classLine != null && subjectsLine != null)
        WorkspaceBuildItem(subjectsLine!, true),
      WorkspaceBuildItem(
        progress.newGuardians == 0
            ? 'Guardian login (only for a new guardian)'
            : progress.newGuardians == 1
            ? '1 guardian login with a temporary password'
            : '${progress.newGuardians} guardian logins with temporary passwords',
        progress.newGuardians > 0,
      ),
    ];
    return WorkspaceSummary(
      title: 'One submission creates',
      items: items,
      details: [
        if (studentFacts != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              studentFacts!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (progress.blockers.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Still needed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                for (final blocker in progress.blockers)
                  Text(
                    '• $blocker',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
          ),
      ],
      rules: const [
        'No student login is ever created - only linked guardians sign in.',
        'A new guardian gets a login with a temporary password, shown once after registration.',
        'Admission, class placement and guardian links are recorded in the audit log.',
        'Moving a student to another class later keeps the class history.',
      ],
    );
  }
}
