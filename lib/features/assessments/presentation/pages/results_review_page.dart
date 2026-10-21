import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/errors/rpc_error.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_dialogs.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/grade_repository.dart';
import '../../data/review_workspace_repository.dart';
import '../../domain/mark_sheet.dart';

final _reviewQueueProvider = FutureProvider.autoDispose<List<ReviewQueueItem>>(
  (ref) => ReviewWorkspaceRepository().queue(),
);

/// Outcome of a decision made in this session, shown in place of the buttons.
class _Decision {
  final String label;
  final StatusTone tone;
  final String text;
  final DateTime at;
  const _Decision(this.label, this.tone, this.text, this.at);
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _stamp(DateTime? d) =>
    d == null ? '—' : '${formatUiDate(d)}, ${_hhmm(d)}';

/// Head Teacher review workspace (route `/results/review`).
///
/// A queue of submitted assessments awaiting a decision on the left; the
/// opened sheet on the right with completeness, missing marks, statistics and
/// entry context. Approving publishes through `publish_assessment_results`.
///
/// "Return to teacher" is shown disabled: the database has no return or
/// reopen action (grades are only DRAFT or SUBMITTED, and the Head Teacher
/// cannot edit grade rows), so inventing one in the app would be unsafe.
class ResultsReviewPage extends ConsumerStatefulWidget {
  /// Assessment to open first (`/results/review?assessment=<id>`).
  final String? initialAssessmentId;

  const ResultsReviewPage({super.key, this.initialAssessmentId});

  @override
  ConsumerState<ResultsReviewPage> createState() => _ResultsReviewPageState();
}

class _ResultsReviewPageState extends ConsumerState<ResultsReviewPage> {
  String? _selectedId;
  bool _selectionChosen = false;
  String _query = '';
  final _search = TextEditingController();

  final Set<String> _checked = {};
  final Map<String, _Decision> _decisions = {};
  final Map<String, ReviewDetail> _details = {};

  ReviewDetail? _detail;
  bool _detailLoading = false;
  Object? _detailError;
  int _detailToken = 0;

  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _role {
    final active = ref.read(activeWorkspaceRoleProvider);
    return active.isEmpty
        ? ref.read(authProvider).user?.roleName ?? ''
        : active;
  }

  // ── Selection & loading ────────────────────────────────────────────────────

  void _chooseInitial(List<ReviewQueueItem> items) {
    if (_selectionChosen) return;
    _selectionChosen = true;
    if (items.isEmpty) return;
    final wanted = widget.initialAssessmentId;
    final target = items.firstWhere(
      (i) => i.assessmentId == wanted,
      orElse: () => items.first,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(target);
    });
  }

  Future<void> _open(ReviewQueueItem item) async {
    final token = ++_detailToken;
    setState(() {
      _selectedId = item.assessmentId;
      _detail = _details[item.assessmentId];
      _detailLoading = _detail == null;
      _detailError = null;
    });
    if (_detail != null) return;
    try {
      final detail = await ReviewWorkspaceRepository().detail(item);
      if (!mounted) return;
      _details[item.assessmentId] = detail;
      if (token != _detailToken) {
        setState(() {});
        return;
      }
      setState(() {
        _detail = detail;
        _detailLoading = false;
      });
    } catch (e) {
      if (mounted && token == _detailToken) {
        setState(() {
          _detailLoading = false;
          _detailError = e;
        });
      }
    }
  }

  void _refresh() {
    _decisions.clear();
    _checked.clear();
    _details.clear();
    _detail = null;
    _selectedId = null;
    _selectionChosen = false;
    ref.invalidate(_reviewQueueProvider);
    setState(() {});
  }

  ReviewQueueItem? _nextPending(List<ReviewQueueItem> items, String afterId) {
    for (final i in items) {
      if (i.assessmentId != afterId &&
          !_decisions.containsKey(i.assessmentId)) {
        return i;
      }
    }
    return null;
  }

  // ── Decisions ──────────────────────────────────────────────────────────────

  Future<void> _publish(
    ReviewDetail detail, {
    required bool withMissing,
  }) async {
    final item = detail.item;
    final missing = detail.stats.missing;
    final confirmed = await showConfirmDialog(
      context,
      title: withMissing ? 'Publish with missing marks' : 'Approve and publish',
      message:
          'Publish ${detail.awaitingCount} grade(s) for ${item.name} '
          '(${item.subjectName}, ${item.className})? Guardians whose fees are '
          'cleared will be able to see them, and a published score can only '
          'be changed through an approved correction request.'
          '${withMissing ? ' $missing student(s) have no mark; they are not '
                    'covered by this publication.' : ''}',
      confirmLabel: withMissing ? 'Publish anyway' : 'Publish',
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final count = await GradeRepository().publishAssessment(
        item.assessmentId,
      );
      if (!mounted) return;
      setState(() {
        _decisions[item.assessmentId] = _Decision(
          'Approved and published',
          StatusTone.success,
          'Published $count grade(s) for ${item.name}. Guardians whose fee '
              'accounts allow it can now see them.',
          DateTime.now(),
        );
        _checked.remove(item.assessmentId);
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(rpcErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnToTeacher(ReviewDetail detail) async {
    final item = detail.item;
    final reason = await showReasonDialog(
      context,
      title: 'Return to teacher',
      message:
          'Send ${item.name} (${item.subjectName}, ${item.className}) back to '
          'the teacher as a draft so the marks can be corrected and '
          'resubmitted. The teacher is notified with your reason (at least 10 '
          'characters).',
      confirmLabel: 'Return sheet',
      label: 'Reason for the teacher',
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final count = await GradeRepository().returnToTeacher(
        assessmentId: item.assessmentId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _decisions[item.assessmentId] = _Decision(
          'Returned to teacher',
          StatusTone.warning,
          'Returned $count grade(s) for ${item.name} to the teacher: $reason',
          DateTime.now(),
        );
        _checked.remove(item.assessmentId);
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(rpcErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishSelected(List<ReviewQueueItem> items) async {
    final chosen = [
      for (final i in items)
        if (_checked.contains(i.assessmentId) &&
            !_decisions.containsKey(i.assessmentId))
          i,
    ];
    if (chosen.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final complete = <ReviewDetail>[];
    final skipped = <String>[];
    try {
      for (final item in chosen) {
        final detail =
            _details[item.assessmentId] ??
            await ReviewWorkspaceRepository().detail(item);
        _details[item.assessmentId] = detail;
        final stats = detail.stats;
        if (stats.missing == 0 && stats.invalid == 0 && stats.total > 0) {
          complete.add(detail);
        } else {
          skipped.add(item.name);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(rpcErrorMessage(e))));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (complete.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'None of the selected sheets is complete, so nothing was '
            'published. Open each one to see the missing marks.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Publish selected sheets',
      message:
          'Publish ${complete.length} complete sheet(s) together? Guardians '
          'whose fees are cleared will be able to see them, and published '
          'scores can only be changed through approved correction requests.'
          '${skipped.isEmpty ? '' : ' ${skipped.length} selected sheet(s) are '
                    'incomplete and will be skipped: ${skipped.join(', ')}.'}',
      confirmLabel: 'Publish ${complete.length}',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    var published = 0;
    final failed = <String>[];
    for (final detail in complete) {
      try {
        final count = await GradeRepository().publishAssessment(
          detail.item.assessmentId,
        );
        published++;
        _decisions[detail.item.assessmentId] = _Decision(
          'Approved and published',
          StatusTone.success,
          'Published $count grade(s) in a batch of ${complete.length}.',
          DateTime.now(),
        );
        _checked.remove(detail.item.assessmentId);
      } catch (e) {
        failed.add('${detail.item.name}: ${rpcErrorMessage(e)}');
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$published sheet(s) published'
          '${failed.isEmpty ? '.' : '; ${failed.length} failed - ${failed.join('; ')}'}',
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(_reviewQueueProvider);
    return UiPage(
      children: [
        PageHead(
          kicker: 'Results',
          title: 'Review workspace',
          subtitle:
              'Submitted result sheets waiting for your decision. Open one, '
              'check it is complete, then approve and publish.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: _refresh,
            ),
            UiButton.secondary(
              'Correction requests',
              icon: Icons.rule_outlined,
              onPressed: () => context.go('/results/corrections'),
            ),
            UiButton.secondary(
              'Publish results',
              icon: Icons.publish_outlined,
              onPressed: () => context.go('/results/publish'),
            ),
          ],
        ),
        queue.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading submitted sheets…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_reviewQueueProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.task_alt_outlined,
                  title: 'Nothing waiting for review',
                  message:
                      'Result sheets appear here after a teacher submits '
                      'them and until they are published.',
                ),
              );
            }
            _chooseInitial(items);
            return SplitLayout(
              mainFlex: 42,
              sideFlex: 100,
              main: _queuePanel(items),
              side: _detailPanel(items),
            );
          },
        ),
      ],
    );
  }

  // ── Queue ──────────────────────────────────────────────────────────────────

  Widget _queuePanel(List<ReviewQueueItem> items) {
    final q = _query.trim().toLowerCase();
    final visible = [
      for (final i in items)
        if (q.isEmpty ||
            '${i.name} ${i.subjectName} ${i.className} ${i.teacherName}'
                .toLowerCase()
                .contains(q))
          i,
    ];
    final pending = items
        .where((i) => !_decisions.containsKey(i.assessmentId))
        .length;
    final checkedCount = _checked
        .where((id) => !_decisions.containsKey(id))
        .length;
    final canPublish = canPublishResults(_role);
    return Panel(
      title: 'Review queue',
      trailing: PanelNote('$pending pending'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiToolbar(
            searchHint: 'Search subject, class or teacher',
            controller: _search,
            onSearch: (v) => setState(() => _query = v),
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nothing matches that search.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _queueRow(item, canPublish),
            ),
          if (canPublish) ...[
            const SizedBox(height: 4),
            Text(
              checkedCount == 0
                  ? 'Tick sheets to publish several together. Incomplete '
                        'sheets are skipped.'
                  : '$checkedCount sheet(s) selected',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            UiButton(
              'Publish selected ($checkedCount)',
              icon: Icons.done_all_rounded,
              expand: true,
              onPressed: checkedCount == 0 || _busy
                  ? null
                  : () => _publishSelected(items),
            ),
          ],
        ],
      ),
    );
  }

  Widget _queueRow(ReviewQueueItem item, bool canPublish) {
    final decision = _decisions[item.assessmentId];
    final cached = _details[item.assessmentId];
    final selected = item.assessmentId == _selectedId;
    final StatusPill pill;
    if (decision != null) {
      pill = StatusPill(decision.label, tone: decision.tone);
    } else if (cached != null) {
      final stats = cached.stats;
      pill = stats.missing > 0 || stats.invalid > 0
          ? StatusPill(
              '${stats.missing + stats.invalid} to fix',
              tone: StatusTone.warning,
            )
          : const StatusPill('Complete', tone: StatusTone.success);
    } else {
      pill = const StatusPill('Awaiting');
    }
    return Material(
      color: selected ? AppColors.primarySurface : AppColors.background,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          if (canPublish)
            Checkbox(
              value: _checked.contains(item.assessmentId) && decision == null,
              onChanged: decision != null || _busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        _checked.add(item.assessmentId);
                      } else {
                        _checked.remove(item.assessmentId);
                      }
                    }),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _open(item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.title} - ${item.name}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (item.teacherName.isNotEmpty) item.teacherName,
                              '${item.awaitingGrades} marks',
                              if (item.lastSubmittedAt != null)
                                _stamp(item.lastSubmittedAt),
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    pill,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  Widget _detailPanel(List<ReviewQueueItem> items) {
    if (_detailLoading) {
      return const UiCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: LoadingState(message: 'Loading the result sheet…'),
        ),
      );
    }
    if (_detailError != null) {
      final item = items.firstWhere(
        (i) => i.assessmentId == _selectedId,
        orElse: () => items.first,
      );
      return UiCard(
        child: ErrorState(error: _detailError!, onRetry: () => _open(item)),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const UiCard(
        child: UiEmptyState(
          icon: Icons.touch_app_outlined,
          title: 'Open a sheet',
          message: 'Choose a result sheet from the queue to review it.',
        ),
      );
    }
    return _sheetDetail(detail, items);
  }

  Widget _sheetDetail(ReviewDetail detail, List<ReviewQueueItem> items) {
    final item = detail.item;
    final stats = detail.stats;
    final decision = _decisions[item.assessmentId];
    final canPublish = canPublishResults(_role);
    final avg = stats.averagePercent;
    final missingNames = detail.missingNames;
    final invalidNames = detail.invalidNames;
    final next = _nextPending(items, item.assessmentId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (decision != null) ...[
          UiNotice(
            '${decision.label}. ${decision.text} (${_hhmm(decision.at)})',
            tone: decision.tone,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 10),
          UiCard(
            color: AppColors.primarySurface,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 12,
              children: [
                Text(
                  next == null
                      ? 'All caught up. No pending sheets in the queue.'
                      : 'Next pending: ${next.title} - ${next.name}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (next != null)
                  UiButton(
                    'Next pending record',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => _open(next),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Panel(
          title: '${item.title} - ${item.name}',
          trailing: decision != null
              ? StatusPill(decision.label, tone: decision.tone)
              : const StatusPill('Awaiting decision'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailLine(
                'Teacher',
                item.teacherName.isEmpty ? '—' : item.teacherName,
              ),
              DetailLine('Class', item.className),
              DetailLine(
                'Assessment',
                '${item.name} · ${item.type.replaceAll('_', ' ')} · out of '
                    '${formatScore(item.maxScore)}',
              ),
              DetailLine(
                'Period',
                item.periodLabel.isEmpty ? '—' : item.periodLabel,
              ),
              DetailLine('Last submitted change', _stamp(item.lastSubmittedAt)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          columns: 4,
          mediumColumns: 2,
          phoneColumns: 2,
          children: [
            MetricCard(
              icon: Icons.fact_check_outlined,
              label: 'Completeness',
              value: '${stats.accounted} of ${stats.total}',
              note: stats.missing + stats.invalid == 0
                  ? 'Every student accounted for'
                  : '${stats.missing + stats.invalid} to fix',
              noteTone: stats.missing + stats.invalid == 0
                  ? StatusTone.success
                  : StatusTone.warning,
            ),
            MetricCard(
              icon: Icons.functions_rounded,
              label: 'Average',
              value: avg == null ? '—' : '${formatScore(avg)}%',
              note: avg == null ? null : 'Grade ${gradeLetter(avg)}',
              noteTone: StatusTone.neutral,
            ),
            MetricCard(
              icon: Icons.swap_vert_rounded,
              label: 'High / low',
              value: stats.highest == null
                  ? '—'
                  : '${formatScore(stats.highest!)} / ${formatScore(stats.lowest!)}',
              noteTone: StatusTone.neutral,
            ),
            MetricCard(
              icon: Icons.verified_outlined,
              label: 'Pass rate',
              value: stats.passRatePercent == null
                  ? '—'
                  : '${stats.passRatePercent}%',
              note: 'At or above 50%',
              noteTone: StatusTone.neutral,
            ),
          ],
        ),
        if (stats.total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stats.completion,
                minHeight: 6,
                color: stats.missing + stats.invalid == 0
                    ? AppColors.success
                    : AppColors.warning,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
          ),
        if (stats.total == 0)
          const UiNotice(
            'No enrolled students were found for this class, so completeness '
            'cannot be checked.',
            tone: StatusTone.warning,
            icon: Icons.info_outline,
          ),
        if (missingNames.isNotEmpty)
          UiNotice(
            '${missingNames.length} missing '
            '${missingNames.length == 1 ? 'mark' : 'marks'}: '
            '${_names(missingNames)}. The sheet is not complete.',
            tone: StatusTone.warning,
            icon: Icons.warning_amber_rounded,
          ),
        if (invalidNames.isNotEmpty)
          UiNotice(
            'Marks outside 0 to ${formatScore(item.maxScore)} for: '
            '${_names(invalidNames)}.',
            tone: StatusTone.danger,
            icon: Icons.error_outline,
          ),
        const SizedBox(height: 14),
        Panel(
          title: 'Mark distribution',
          trailing: const PanelNote('Bands of 10%'),
          child: _BandsChart(markBands(detail.validScores, item.maxScore)),
        ),
        const SizedBox(height: 14),
        _contextPanel(detail),
        const SizedBox(height: 14),
        if (decision == null) _decisionBar(detail, canPublish, stats),
      ],
    );
  }

  String _names(List<String> names) {
    const shown = 8;
    if (names.length <= shown) return names.join(', ');
    return '${names.take(shown).join(', ')} and ${names.length - shown} more';
  }

  Widget _contextPanel(ReviewDetail detail) {
    final authors = detail.authors;
    return Panel(
      title: 'Entry context',
      trailing: const PanelNote('From the stored marks'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailLine(
            'Marks entered by',
            authors.isEmpty ? '—' : authors.join(', '),
          ),
          DetailLine('First mark entered', _stamp(detail.firstEntered)),
          DetailLine('Last change', _stamp(detail.lastChanged)),
          DetailLine(
            'Submitted, not published',
            '${detail.awaitingCount} of ${detail.grades.length} marks',
          ),
          DetailLine(
            'Pending correction requests',
            '${detail.pendingCorrections}',
            valueColor: detail.pendingCorrections > 0
                ? AppColors.warning
                : null,
            trailing: detail.pendingCorrections > 0
                ? PanelNote(
                    'Open',
                    onTap: () => context.go('/results/corrections'),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            'Teacher comments are written per student, not per assessment, '
            'so they are not shown on a result sheet. The audit log is '
            'visible to Super Users only.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: UiButton.secondary(
              'Teacher comments',
              icon: Icons.comment_outlined,
              onPressed: () => context.go('/teacher/comments'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decisionBar(ReviewDetail detail, bool canPublish, SheetStats stats) {
    if (!canPublish) {
      return const UiNotice(
        'Only a Head Teacher or Super User can publish results.',
        tone: StatusTone.info,
        icon: Icons.lock_outline,
      );
    }
    final incomplete =
        stats.missing > 0 || stats.invalid > 0 || stats.total == 0;
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            spacing: 12,
            children: [
              const Text(
                'Decision',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  UiButton.secondary(
                    'Return with reason',
                    icon: Icons.undo_rounded,
                    onPressed: _busy ? null : () => _returnToTeacher(detail),
                  ),
                  if (incomplete && stats.total > 0 && stats.invalid == 0)
                    UiButton.secondary(
                      'Publish with ${stats.missing} missing',
                      icon: Icons.publish_outlined,
                      onPressed: _busy
                          ? null
                          : () => _publish(detail, withMissing: true),
                    ),
                  UiButton(
                    _busy ? 'Publishing…' : 'Approve and publish',
                    icon: Icons.check_rounded,
                    onPressed: _busy || incomplete
                        ? null
                        : () => _publish(detail, withMissing: false),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ten-band histogram of marks (0-9% ... 90-100%), plain bars.
class _BandsChart extends StatelessWidget {
  final List<int> bands;
  const _BandsChart(this.bands);

  @override
  Widget build(BuildContext context) {
    final peak = bands.fold<int>(0, (m, v) => v > m ? v : m);
    if (peak == 0) {
      return const Text(
        'No valid marks yet.',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Semantics(
      label: 'Histogram of marks in ten percentage bands',
      child: SizedBox(
        height: 130,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bands.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${bands[i]}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: bands[i] == 0 ? 2 : 90 * bands[i] / peak,
                        decoration: BoxDecoration(
                          color: i < 5
                              ? AppColors.primaryLight
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${i * 10}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
