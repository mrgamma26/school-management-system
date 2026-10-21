import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/weeding_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/auth/permission_helper.dart';
import '../../../../core/auth/school_role_access.dart';
import '../../../../core/errors/rpc_error.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';

String _pretty(Object? value) => (value?.toString() ?? '')
    .replaceAll('_', ' ')
    .replaceFirstMapped(
      RegExp(r'^[A-Z]+'),
      (m) => m[0]![0] + m[0]!.substring(1).toLowerCase(),
    );

final _flagStudentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final rows = await supabase
          .from('student')
          .select('studentid, firstname, lastname')
          .order('firstname');
      return List<Map<String, dynamic>>.from(rows as List);
    });

// Providers

final _weedingYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term, form')
      .order('academicyear', ascending: false)
      .order('form')
      .order('term');
  return List<Map<String, dynamic>>.from(rows as List);
});

final _weedingReviewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      yearId,
    ) async {
      return WeedingRepository().allReviews(yearId);
    });

// Page

/// Weeding (withdrawal) reviews for a selected academic year.
/// Head Teacher decides: WEED_OUT or RETAIN.
class WeedingReviewsPage extends ConsumerStatefulWidget {
  const WeedingReviewsPage({super.key});

  @override
  ConsumerState<WeedingReviewsPage> createState() => _WeedingReviewsPageState();
}

class _WeedingReviewsPageState extends ConsumerState<WeedingReviewsPage> {
  String? _yearId;
  String _filter = 'ALL'; // ALL | PENDING | WEED_OUT | RETAIN

  bool get _canDecide {
    final permHelper = ref.watch(permissionHelperProvider);
    return permHelper.maybeWhen(
      data: (perm) =>
          perm != null &&
          (perm.canDecideWeeding ||
              perm.has('weeding:decide') ||
              schoolRole(perm.roleName) == 'HEAD_TEACHER'),
      orElse: () => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_weedingYearsProvider);

    return UiPage(
      children: [
        PageHead(
          kicker: 'Assessments',
          title: 'Weeding Reviews',
          subtitle:
              'Student status reviews decided by the Head Teacher with a recorded reason.',
          actions: [
            if (_yearId != null && _canDecide)
              UiButton(
                'Flag Student',
                icon: Icons.flag_outlined,
                onPressed: () => _showFlagDialog(),
              ),
          ],
        ),
        yearsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading academic periods…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_weedingYearsProvider),
          ),
          data: (years) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Year selector
              UiCard(
                padding: const EdgeInsets.all(12),
                child: UiField(
                  label: 'Academic period',
                  child: DropdownButtonFormField<String>(
                    initialValue: _yearId,
                    hint: const Text('Select academic year'),
                    items: years.map((y) {
                      final id = y['academicyearid'] as String;
                      final label =
                          '${y['academicyear']}/${(y['academicyear'] as int) + 1} • '
                          '${_pretty(y['form'])} • ${_pretty(y['term'])}';
                      return DropdownMenuItem(value: id, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setState(() => _yearId = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter chips
              if (_yearId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in const [
                        'ALL',
                        'PENDING',
                        'WEED_OUT',
                        'RETAIN',
                      ])
                        FilterChipBox(
                          f.replaceAll('_', ' '),
                          selected: _filter == f,
                          onTap: () => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),

              // List
              if (_yearId == null)
                const UiCard(
                  child: UiEmptyState(
                    icon: Icons.manage_search_outlined,
                    title: 'Select an academic period',
                    message: 'Select a year to view weeding reviews.',
                  ),
                )
              else
                _WeedingList(
                  yearId: _yearId!,
                  filter: _filter,
                  canDecide: _canDecide,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showFlagDialog() async {
    final avgCtrl = TextEditingController();
    String? studentId;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Flag Student for Review'),
          content: SizedBox(
            width: 420,
            child: Consumer(
              builder: (ctx, ref, _) {
                final students = ref.watch(_flagStudentsProvider);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose the student and enter their cumulative average '
                      'for the period selected above.',
                    ),
                    const SizedBox(height: 12),
                    students.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(rpcErrorMessage(e)),
                      data: (list) => DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Student *',
                        ),
                        items: [
                          for (final r in list)
                            DropdownMenuItem(
                              value: r['studentid'] as String,
                              child: Text('${r['firstname']} ${r['lastname']}'),
                            ),
                        ],
                        onChanged: (v) => setDialogState(() => studentId = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: avgCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cumulative average (0-100) *',
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final avg = double.tryParse(avgCtrl.text.trim()) ?? -1;
                if (studentId == null || avg < 0 || avg > 100) {
                  setDialogState(
                    () => error =
                        'Choose a student and an average from 0 to 100.',
                  );
                  return;
                }
                try {
                  await WeedingRepository().flagStudent(
                    studentId: studentId!,
                    academicYearId: _yearId!,
                    cumulativeAverage: avg,
                  );
                  ref.invalidate(_weedingReviewsProvider(_yearId!));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialogState(() => error = rpcErrorMessage(e));
                }
              },
              child: const Text('Flag'),
            ),
          ],
        ),
      ),
    );
    avgCtrl.dispose();
  }
}

// Weeding list

class _WeedingList extends ConsumerWidget {
  final String yearId;
  final String filter;
  final bool canDecide;

  const _WeedingList({
    required this.yearId,
    required this.filter,
    required this.canDecide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_weedingReviewsProvider(yearId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: LoadingState(message: 'Loading reviews…'),
      ),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(_weedingReviewsProvider(yearId)),
      ),
      data: (reviews) {
        final filtered = filter == 'ALL'
            ? reviews
            : reviews.where((r) => r['decision'] == filter).toList();

        if (filtered.isEmpty) {
          return UiCard(
            child: UiEmptyState(
              icon: Icons.fact_check_outlined,
              title: filter == 'PENDING'
                  ? 'No pending weeding reviews'
                  : 'No ${filter.replaceAll('_', ' ')} reviews found',
            ),
          );
        }

        return DataTableCard(
          columns: const [
            UiColumn('Student', flex: 16),
            UiColumn('Average', flex: 7),
            UiColumn('Flagged', flex: 9, hideOnPhone: true),
            UiColumn('Reason', flex: 14, hideOnPhone: true),
            UiColumn('Decision', width: 124),
          ],
          rows: [
            for (final r in filtered)
              () {
                final student = r['student'] as Map<String, dynamic>;
                final name = '${student['firstname']} ${student['lastname']}';
                final decision = r['decision'] as String;
                final reason = r['decisionreason'] as String?;
                final decider = r['staff'] as Map<String, dynamic>?;
                return UiTableRow([
                  PersonCell(
                    name,
                    subtitle: decider == null
                        ? null
                        : 'By ${decider['firstname']} ${decider['lastname']}',
                  ),
                  UiCellText('${r['cumulativeaverage'] ?? '—'}', bold: true),
                  UiCellText('${r['flaggeddate'] ?? '—'}'),
                  UiCellText(
                    reason != null && reason.isNotEmpty ? reason : '—',
                  ),
                  decision == 'PENDING' && canDecide
                      ? _WeedButtons(
                          weedingId: r['weedingid'] as String,
                          yearId: yearId,
                          studentName: name,
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: StatusPill(
                            decision.replaceAll('_', ' '),
                            tone: _tone(decision),
                          ),
                        ),
                ]);
              }(),
          ],
        );
      },
    );
  }

  StatusTone _tone(String d) => switch (d) {
    'WEED_OUT' => StatusTone.danger,
    'RETAIN' => StatusTone.success,
    _ => StatusTone.warning,
  };
}

// Weed buttons

class _WeedButtons extends ConsumerWidget {
  final String weedingId;
  final String yearId;
  final String studentName;

  const _WeedButtons({
    required this.weedingId,
    required this.yearId,
    required this.studentName,
  });

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    String decision,
  ) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${decision == 'WEED_OUT' ? 'Remove' : 'Retain'} $studentName',
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: decision == 'WEED_OUT'
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, reasonCtrl.text.trim());
            },
            child: Text(decision == 'WEED_OUT' ? 'Confirm Remove' : 'Retain'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null) return;

    final actor = ref.read(authProvider).user!;
    final staffRow = await supabase
        .from('staff')
        .select('staffid')
        .eq('userid', actor.userId)
        .single();
    final staffId = staffRow['staffid'] as String;

    try {
      await WeedingRepository().decide(
        weedingId: weedingId,
        staffId: staffId,
        decision: decision,
        reason: reason,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(rpcErrorMessage(e))));
      }
      return;
    }

    await AuditService().log(
      userId: actor.userId,
      action: 'WEEDING_DECISION',
      tableName: 'weedingreview',
      recordId: weedingId,
      actorRole: actor.roleName,
      newValue: {
        'decision': decision,
        'student': studentName,
        'reason': reason,
      },
    );

    ref.invalidate(_weedingReviewsProvider(yearId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          tooltip: 'Retain',
          onPressed: () => _decide(context, ref, 'RETAIN'),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.red),
          tooltip: 'Weed Out',
          onPressed: () => _decide(context, ref, 'WEED_OUT'),
        ),
      ],
    );
  }
}
