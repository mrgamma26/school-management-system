import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/errors/rpc_error.dart';
import '../../../../widgets/ui_dialogs.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_record_list.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/grade_repository.dart';
import '../../data/results_review_repository.dart';

final _publishableAssessmentsProvider =
    FutureProvider.autoDispose<List<PublishableAssessment>>(
      (ref) => ResultsReviewRepository().listAssessmentsForPublishing(),
    );

({String label, StatusTone tone}) _stateOf(PublishableAssessment a) {
  if (a.totalGrades == 0) {
    return (label: 'No grades', tone: StatusTone.neutral);
  }
  if (a.unpublishedGrades == 0) {
    return (label: 'Published', tone: StatusTone.success);
  }
  if (a.publishedGrades == 0) {
    return (label: 'Not published', tone: StatusTone.warning);
  }
  return (label: 'Partly published', tone: StatusTone.warning);
}

/// Screen 34 - Publish results.
///
/// Lists assessments with how many of their grades are published. The Head
/// Teacher or Super User publishes through `publish_assessment_results`, which
/// publishes every unpublished grade of the assessment in one step.
class PublishResultsPage extends ConsumerStatefulWidget {
  const PublishResultsPage({super.key});

  @override
  ConsumerState<PublishResultsPage> createState() => _PublishResultsPageState();
}

class _PublishResultsPageState extends ConsumerState<PublishResultsPage> {
  String? _publishingId;

  Future<void> _publish(PublishableAssessment a) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Publish results',
      message:
          'Publish ${a.unpublishedGrades} grade(s) for ${a.name} '
          '(${a.subjectName}, ${a.className})? Guardians whose fees are '
          'cleared will be able to see them, and a published score can only '
          'be changed through an approved correction request.',
      confirmLabel: 'Publish',
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _publishingId = a.id);
    try {
      final count = await GradeRepository().publishAssessment(a.id);
      ref.invalidate(_publishableAssessmentsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Published $count grade(s) for ${a.name}.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(rpcErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _publishingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_publishableAssessmentsProvider);
    final active = ref.watch(activeWorkspaceRoleProvider);
    final role = active.isEmpty
        ? ref.watch(authProvider).user?.roleName ?? ''
        : active;
    final canPublish = canPublishResults(role);

    return UiPage(
      children: [
        PageHead(
          kicker: 'Results',
          title: 'Publish Results',
          subtitle:
              'Release assessment results to guardians once marks are final.',
          actions: [
            if (canPublish)
              UiButton.secondary(
                'Review workspace',
                icon: Icons.rate_review_outlined,
                onPressed: () => context.go('/results/review'),
              ),
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_publishableAssessmentsProvider),
            ),
          ],
        ),
        RecordListView<PublishableAssessment>(
          data: data,
          onRetry: () => ref.invalidate(_publishableAssessmentsProvider),
          loadingMessage: 'Loading assessments…',
          searchHint: 'Search assessment, subject or class',
          searchText: (a) => '${a.name} ${a.subjectName} ${a.className}',
          filters: const ['All', 'Not published', 'Partly published', 'Published'],
          matchesFilter: (a, f) => _stateOf(a).label == f,
          emptyIcon: Icons.assignment_turned_in_outlined,
          emptyTitle: 'No assessments yet',
          emptyMessage: 'Assessments appear here once teachers create them.',
          header: (items) => AdaptiveGrid(
            columns: 3,
            phoneColumns: 1,
            children: [
              MetricCard(
                icon: Icons.assignment_outlined,
                label: 'Assessments',
                value: '${items.length}',
                noteTone: StatusTone.neutral,
              ),
              MetricCard(
                icon: Icons.pending_actions_outlined,
                label: 'With unpublished grades',
                value: '${items.where((a) => a.unpublishedGrades > 0).length}',
                note: 'Waiting to be published',
                noteTone: StatusTone.warning,
              ),
              MetricCard(
                icon: Icons.verified_outlined,
                label: 'Fully published',
                value:
                    '${items.where((a) => a.totalGrades > 0 && a.unpublishedGrades == 0).length}',
                noteTone: StatusTone.neutral,
              ),
            ],
          ),
          columns: const [
            UiColumn('Assessment', flex: 16),
            UiColumn('Class', flex: 9, hideOnPhone: true),
            UiColumn('Max', flex: 5, hideOnPhone: true),
            UiColumn('Published', flex: 8),
            UiColumn('Status', width: 130),
            UiColumn('', width: 110),
          ],
          rowOf: (a) {
            final state = _stateOf(a);
            return UiTableRow([
              PersonCell(a.name, subtitle: '${a.subjectName} - ${a.type}'),
              UiCellText(a.className),
              UiCellText(
                a.maxScore.toStringAsFixed(a.maxScore % 1 == 0 ? 0 : 2),
              ),
              UiCellText('${a.publishedGrades} of ${a.totalGrades}'),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(state.label, tone: state.tone),
              ),
              if (canPublish && a.unpublishedGrades > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _publishingId != null ? null : () => _publish(a),
                    child: Text(_publishingId == a.id ? 'Publishing…' : 'Publish'),
                  ),
                )
              else
                const SizedBox.shrink(),
            ]);
          },
        ),
      ],
    );
  }
}
