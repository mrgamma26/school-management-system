import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/can.dart';
import '../../data/progression_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../academics/domain/models/academic_year.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _progressionYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term, form')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

final _progressionReviewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      yearId,
    ) async {
      return ProgressionRepository().allReviews(yearId);
    });

final _progressionStudentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      periodId,
    ) async {
      final selected = await supabase
          .from('academicyear')
          .select('academicyear, form')
          .eq('academicyearid', periodId)
          .single();
      final periods = List<Map<String, dynamic>>.from(
        await supabase
            .from('academicyear')
            .select('startdate, enddate')
            .eq('academicyear', selected['academicyear'])
            .eq('form', selected['form']),
      );
      if (periods.isEmpty) return const [];
      final starts =
          periods.map((p) => DateTime.parse(p['startdate'] as String)).toList()
            ..sort();
      final ends =
          periods.map((p) => DateTime.parse(p['enddate'] as String)).toList()
            ..sort();
      final schoolStart = starts.first;
      final schoolEnd = ends.last;
      final histories = List<Map<String, dynamic>>.from(
        await supabase
            .from('studentclasshistory')
            .select(
              'studentid, enrollmentdate, enddate, '
              'student(firstname, lastname), class(form)',
            ),
      );
      final students = <String, Map<String, dynamic>>{};
      for (final history in histories) {
        final classroom = history['class'] as Map?;
        if (classroom?['form']?.toString() != selected['form']?.toString()) {
          continue;
        }
        final enrollment = DateTime.parse(history['enrollmentdate'] as String);
        final end = DateTime.tryParse(history['enddate']?.toString() ?? '');
        if (enrollment.isAfter(schoolEnd) ||
            (end != null && end.isBefore(schoolStart))) {
          continue;
        }
        students[history['studentid'] as String] = history;
      }
      final result = students.values.toList();
      result.sort((a, b) {
        final aStudent = a['student'] as Map?;
        final bStudent = b['student'] as Map?;
        return '${aStudent?['firstname']} ${aStudent?['lastname']}'.compareTo(
          '${bStudent?['firstname']} ${bStudent?['lastname']}',
        );
      });
      return result;
    });

// ── Page ──────────────────────────────────────────────────────────────────────

/// Progression reviews for a selected academic year.
/// Head Teacher can approve / retain. Admin can view all.
class ProgressionReviewsPage extends ConsumerStatefulWidget {
  const ProgressionReviewsPage({super.key});

  @override
  ConsumerState<ProgressionReviewsPage> createState() =>
      _ProgressionReviewsPageState();
}

class _ProgressionReviewsPageState
    extends ConsumerState<ProgressionReviewsPage> {
  String? _yearId;
  String _filter = 'ALL'; // ALL | PENDING | PROMOTED | RETAINED

  bool get _canDecide {
    return ref
        .watch(permissionsProvider)
        .maybeWhen(
          data: (permissions) => permissions.contains('progression:decide'),
          orElse: () => false,
        );
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_progressionYearsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progression Reviews'),
        actions: [
          if (_yearId != null)
            Can(
              permission: 'progression:decide',
              child: TextButton.icon(
                onPressed: () => _showCalculateDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Calculate Review'),
              ),
            ),
        ],
      ),
      body: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (years) => Column(
          children: [
            // ── Year selector ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _yearId,
                decoration: const InputDecoration(
                  labelText: 'Academic Year',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                hint: const Text('Select academic year'),
                items: years.map((y) {
                  final id = y['academicyearid'] as String;
                  final label =
                      '${formatAcademicYear(y['academicyear'])} • ${formatFormLevel(y['form']?.toString())} • ${y['term'].toString().replaceAll('_', ' ')}';
                  return DropdownMenuItem(value: id, child: Text(label));
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _yearId = v;
                  });
                },
              ),
            ),

            // ── Filter chips ───────────────────────────────────────────
            if (_yearId != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: ['ALL', 'PENDING', 'PROMOTED', 'RETAINED']
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(f),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 8),

            // ── Review list ────────────────────────────────────────────
            Expanded(
              child: _yearId == null
                  ? const Center(
                      child: Text(
                        'Select a year to view progression reviews',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _ReviewList(
                      yearId: _yearId!,
                      filter: _filter,
                      canDecide: _canDecide,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalculateDialog() async {
    final periodId = _yearId!;
    List<Map<String, dynamic>> students;
    try {
      students = await ref.read(_progressionStudentsProvider(periodId).future);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
      return;
    }
    if (!mounted) return;
    String? studentId;
    Map<String, dynamic>? result;
    bool calculating = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Calculate Annual Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMessage != null) ...[
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: studentId,
                decoration: const InputDecoration(labelText: 'Student *'),
                items: students.map((history) {
                  final student = history['student'] as Map?;
                  return DropdownMenuItem(
                    value: history['studentid'] as String,
                    child: Text(
                      '${student?['firstname']} ${student?['lastname']}',
                    ),
                  );
                }).toList(),
                onChanged: calculating
                    ? null
                    : (value) => setDialogState(() => studentId = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: calculating ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: calculating
                  ? null
                  : () async {
                      if (studentId == null) {
                        setDialogState(
                          () => errorMessage = 'Select a student first.',
                        );
                        return;
                      }
                      setDialogState(() {
                        calculating = true;
                        errorMessage = null;
                      });
                      try {
                        result = await ProgressionRepository()
                            .refreshAnnualReview(
                              studentId: studentId!,
                              academicYearId: periodId,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (error) {
                        setDialogState(
                          () => errorMessage = friendlyError(error),
                        );
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => calculating = false);
                        }
                      }
                    },
              icon: calculating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: const Text('Calculate / Refresh'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      ref.invalidate(_progressionReviewsProvider(periodId));
      await _showEvidence(result!);
    }
  }

  Future<void> _showEvidence(Map<String, dynamic> result) async {
    final terms = (result['terms'] as List? ?? const []).cast<Map>();
    final missing = (result['missing'] as List? ?? const []).cast<Map>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annual Review Evidence'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...terms.map((term) {
                final enrolled = term['enrolled'] == true;
                final average = term['average'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(term['term'].toString().replaceAll('_', ' ')),
                  trailing: Text(
                    enrolled ? '${average ?? '—'}' : '— / Not enrolled',
                  ),
                );
              }),
              const Divider(),
              Text('Annual average: ${result['annualAverage'] ?? '—'}'),
              Text('Recommendation: ${result['recommendation']}'),
              Text('Pass threshold: ${result['passThreshold']}%'),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Missing results',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                ...missing.map(
                  (item) => Text(
                    '• ${item['term'] ?? 'Term'}: ${item['subject'] ?? ''} ${item['reason'] ?? ''}',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Retained for installations that enable manual legacy review creation.
  // ignore: unused_element
  Future<void> _showCreateDialog() async {
    final studentCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Progression Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: studentCtrl,
              decoration: const InputDecoration(labelText: 'Student ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: scoreCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Average Score (0–100)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final sid = studentCtrl.text.trim();
              final score = double.tryParse(scoreCtrl.text.trim()) ?? -1;
              if (sid.isEmpty || score < 0 || score > 100) return;
              await ProgressionRepository().createReview(
                studentId: sid,
                academicYearId: _yearId!,
                averageScore: score,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    studentCtrl.dispose();
    scoreCtrl.dispose();
  }
}

// ── Review list ───────────────────────────────────────────────────────────────

class _ReviewList extends ConsumerWidget {
  final String yearId;
  final String filter;
  final bool canDecide;

  const _ReviewList({
    required this.yearId,
    required this.filter,
    required this.canDecide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_progressionReviewsProvider(yearId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (reviews) {
        final filtered = filter == 'ALL'
            ? reviews
            : reviews.where((r) => r['decision'] == filter).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No $filter reviews found.',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = filtered[i];
            final student = r['student'] as Map<String, dynamic>;
            final name = '${student['firstname']} ${student['lastname']}';
            final decision = r['decision'] as String;
            final avg = r['averagescore'];
            final approver = r['staff'] as Map<String, dynamic>?;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _decisionColor(decision),
                  child: Icon(
                    _decisionIcon(decision),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Average Score: ${avg ?? '—'}'),
                    if (approver != null)
                      Text(
                        'By: ${approver['firstname']} ${approver['lastname']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: decision == 'PENDING' && canDecide
                    ? _DecisionButtons(
                        reviewId: r['reviewid'] as String,
                        yearId: yearId,
                        studentName: name,
                      )
                    : Chip(
                        label: Text(decision),
                        backgroundColor: _decisionColor(
                          decision,
                        ).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _decisionColor(decision),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                isThreeLine: approver != null,
              ),
            );
          },
        );
      },
    );
  }

  Color _decisionColor(String d) => switch (d) {
    'PROMOTED' => Colors.green,
    'RETAINED' => Colors.orange,
    'REJECTED' => Colors.red,
    _ => Colors.grey,
  };

  IconData _decisionIcon(String d) => switch (d) {
    'PROMOTED' => Icons.check_circle,
    'RETAINED' => Icons.pause_circle,
    'REJECTED' => Icons.cancel,
    _ => Icons.hourglass_empty,
  };
}

// ── Decision buttons ──────────────────────────────────────────────────────────

class _DecisionButtons extends ConsumerWidget {
  final String reviewId;
  final String yearId;
  final String studentName;

  const _DecisionButtons({
    required this.reviewId,
    required this.yearId,
    required this.studentName,
  });

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    String decision,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$decision $studentName'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Decision reason *',
            hintText: 'Explain the evidence for this decision',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !context.mounted) return;

    try {
      final repository = ProgressionRepository();
      final targetPeriodId = decision == 'PROMOTED'
          ? await repository.nextAcademicPeriod(yearId)
          : yearId;
      await repository.decideAndPlace(
        reviewId: reviewId,
        decision: decision,
        targetAcademicPeriodId: targetPeriodId,
        reason: reason,
      );
      ref.invalidate(_progressionReviewsProvider(yearId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$studentName was ${decision.toLowerCase()}.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Can(
          permission: 'progression:decide',
          child: IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Promote',
            onPressed: () => _decide(context, ref, 'PROMOTED'),
          ),
        ),
        Can(
          permission: 'progression:decide',
          child: IconButton(
            icon: const Icon(Icons.pause_circle, color: Colors.orange),
            tooltip: 'Retain',
            onPressed: () => _decide(context, ref, 'RETAINED'),
          ),
        ),
      ],
    );
  }
}
