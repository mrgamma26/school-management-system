import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/errors/rpc_error.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_dialogs.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_record_list.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/grade_repository.dart';
import '../../data/results_review_repository.dart';

final _correctionRequestsProvider =
    FutureProvider.autoDispose<List<CorrectionRequestRow>>(
      (ref) => ResultsReviewRepository().listCorrectionRequests(),
    );

StatusTone _toneFor(String status) => switch (status) {
  'PENDING' => StatusTone.warning,
  'APPROVED' => StatusTone.info,
  'COMPLETED' => StatusTone.success,
  'REJECTED' => StatusTone.danger,
  _ => StatusTone.neutral,
};

String _labelFor(String status) =>
    status.isEmpty ? '—' : status[0] + status.substring(1).toLowerCase();

String _score(double? value) =>
    value == null ? '—' : value.toStringAsFixed(value % 1 == 0 ? 0 : 2);

/// Screens 32 and 33 - Result correction requests.
///
/// Teachers see their own requests (and complete approved ones); the Head
/// Teacher and Super User see all requests and approve or reject pending ones.
/// Every action goes through the existing RPCs in [GradeRepository].
class CorrectionRequestsPage extends ConsumerStatefulWidget {
  const CorrectionRequestsPage({super.key});

  @override
  ConsumerState<CorrectionRequestsPage> createState() =>
      _CorrectionRequestsPageState();
}

class _CorrectionRequestsPageState
    extends ConsumerState<CorrectionRequestsPage> {
  bool _busy = false;

  String get _role {
    final active = ref.read(activeWorkspaceRoleProvider);
    return active.isEmpty
        ? ref.read(authProvider).user?.roleName ?? ''
        : active;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(_correctionRequestsProvider);
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(rpcErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(CorrectionRequestRow r) async {
    final reason = await showReasonDialog(
      context,
      title: 'Approve correction',
      message:
          'Approve the correction for ${r.studentName} (${r.assessmentName}, '
          '${r.subjectName})? The teacher will then be able to enter the '
          'corrected score.',
      confirmLabel: 'Approve',
      required: false,
      label: 'Note for the teacher',
    );
    if (reason == null || !mounted) return;
    await _run(
      () => GradeRepository().decideCorrection(
        requestId: r.id,
        approved: true,
        reason: reason,
      ),
      'Correction approved.',
    );
  }

  Future<void> _reject(CorrectionRequestRow r) async {
    final reason = await showReasonDialog(
      context,
      title: 'Reject correction',
      message:
          'Reject the correction for ${r.studentName} (${r.assessmentName})? '
          'The published score stays unchanged.',
      confirmLabel: 'Reject',
      label: 'Reason for rejecting',
    );
    if (reason == null || !mounted) return;
    await _run(
      () => GradeRepository().decideCorrection(
        requestId: r.id,
        approved: false,
        reason: reason,
      ),
      'Correction rejected.',
    );
  }

  Future<void> _complete(CorrectionRequestRow r) async {
    final controller = TextEditingController();
    final max = r.maxScore ?? 100;
    final score = await showDialog<double>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Complete correction'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.studentName} - ${r.assessmentName}. '
                    'Current published score: ${_score(r.oldScore)} '
                    'out of ${_score(max)}. Saving returns the grade to draft '
                    'so it can be submitted and published again.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Corrected score (0 - ${_score(max)})',
                      errorText: error,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final value = validateScore(controller.text, max);
                    if (value == null) {
                      setState(() => error = 'Enter the corrected score.');
                      return;
                    }
                    Navigator.pop(ctx, value);
                  } on FormatException catch (e) {
                    setState(() => error = e.message);
                  }
                },
                child: const Text('Save correction'),
              ),
            ],
          ),
        );
      },
    );
    if (score == null || !mounted) return;
    await _run(
      () => GradeRepository().completeCorrection(requestId: r.id, score: score),
      'Correction saved. The grade is back in draft.',
    );
  }

  Widget _actions(CorrectionRequestRow r) {
    final role = _role;
    final buttons = <Widget>[];
    if (r.isPending && canDecideResultCorrections(role)) {
      buttons.addAll([
        TextButton(
          onPressed: _busy ? null : () => _approve(r),
          child: const Text('Approve'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _reject(r),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Reject'),
        ),
      ]);
    } else if (r.isApproved && canCompleteResultCorrections(role)) {
      buttons.add(
        TextButton(
          onPressed: _busy ? null : () => _complete(r),
          child: const Text('Enter score'),
        ),
      );
    }
    return Wrap(alignment: WrapAlignment.end, children: buttons);
  }

  void _showDetail(CorrectionRequestRow r) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Correction request'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: DialogDetailList([
              ('Student', r.studentName),
              ('Assessment', r.assessmentName),
              ('Subject', r.subjectName),
              ('Class', r.className),
              ('Status', _labelFor(r.status)),
              ('Requested by', r.requestedByName),
              ('Requested', formatUiDate(r.requestedAt)),
              ('Reason', r.reason),
              ('Published score', _score(r.oldScore)),
              ('Corrected score', _score(r.newScore)),
              if (r.decidedAt != null) ('Decided by', r.approvedByName),
              if (r.decidedAt != null) ('Decided', formatUiDate(r.decidedAt)),
              if (r.decisionReason != null)
                ('Decision note', r.decisionReason!),
              if (r.completedAt != null)
                ('Completed', formatUiDate(r.completedAt)),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_correctionRequestsProvider);
    final role = _role;
    final manages = canDecideResultCorrections(role);

    return UiPage(
      children: [
        PageHead(
          kicker: 'Results',
          title: 'Correction Requests',
          subtitle: manages
              ? 'Approve or reject requests to change a published score.'
              : 'Your requests to change a published score, and their outcome.',
          actions: [
            if (manages)
              UiButton.secondary(
                'Review workspace',
                icon: Icons.rate_review_outlined,
                onPressed: () => context.go('/results/review'),
              )
            else if (canCompleteResultCorrections(role))
              UiButton.secondary(
                'Enter marks',
                icon: Icons.edit_note_rounded,
                onPressed: () => context.go('/assessments'),
              ),
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_correctionRequestsProvider),
            ),
          ],
        ),
        RecordListView<CorrectionRequestRow>(
          data: data,
          onRetry: () => ref.invalidate(_correctionRequestsProvider),
          loadingMessage: 'Loading correction requests…',
          searchHint: 'Search student, assessment or teacher',
          searchText: (r) =>
              '${r.studentName} ${r.assessmentName} ${r.subjectName} '
              '${r.className} ${r.requestedByName}',
          filters: const ['All', 'Pending', 'Approved', 'Completed', 'Rejected'],
          matchesFilter: (r, f) => _labelFor(r.status) == f,
          emptyIcon: Icons.fact_check_outlined,
          emptyTitle: 'No correction requests',
          emptyMessage:
              'A published score can only be changed through an approved request.',
          header: (items) => AdaptiveGrid(
            columns: 3,
            phoneColumns: 1,
            children: [
              MetricCard(
                icon: Icons.hourglass_empty_rounded,
                label: 'Pending decision',
                value: '${items.where((r) => r.isPending).length}',
                note: 'Waiting for the Head Teacher',
                noteTone: StatusTone.warning,
              ),
              MetricCard(
                icon: Icons.edit_note_rounded,
                label: 'Approved, score not entered',
                value: '${items.where((r) => r.isApproved).length}',
                note: 'Waiting for the teacher',
                noteTone: StatusTone.neutral,
              ),
              MetricCard(
                icon: Icons.check_circle_outline,
                label: 'Completed',
                value: '${items.where((r) => r.status == 'COMPLETED').length}',
                noteTone: StatusTone.neutral,
              ),
            ],
          ),
          columns: const [
            UiColumn('Student', flex: 16),
            UiColumn('Reason', flex: 14, hideOnPhone: true),
            UiColumn('Score', flex: 8, hideOnPhone: true),
            UiColumn('Requested', flex: 10, hideOnPhone: true),
            UiColumn('Status', width: 100),
            UiColumn('', width: 160),
          ],
          rowOf: (r) => UiTableRow([
            PersonCell(
              r.studentName,
              subtitle: '${r.assessmentName} - ${r.subjectName}, ${r.className}',
            ),
            UiCellText(r.reason),
            UiCellText(
              r.newScore == null
                  ? _score(r.oldScore)
                  : '${_score(r.oldScore)} to ${_score(r.newScore)}',
            ),
            UiCellText(
              '${formatUiDate(r.requestedAt)}\n${r.requestedByName}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(_labelFor(r.status), tone: _toneFor(r.status)),
            ),
            _actions(r),
          ], onTap: () => _showDetail(r)),
        ),
      ],
    );
  }
}
