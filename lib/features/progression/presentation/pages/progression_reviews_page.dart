import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/progression_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _progressionYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
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
  String? _yearLabel;
  String _filter = 'ALL'; // ALL | PENDING | APPROVED | RETAINED

  bool get _canDecide {
    final r = ref.read(authProvider).user?.roleName.toUpperCase() ?? '';
    return r == 'HEAD_TEACHER' || r == 'SYSTEM_ADMIN' || r == 'SUPER_USER';
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_progressionYearsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progression Reviews'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          if (_yearId != null && _canDecide)
            TextButton.icon(
              onPressed: () => _showCreateDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Review'),
            ),
        ],
      ),
      body: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
                  final label = '${y['academicyear']} — ${y['term']}';
                  return DropdownMenuItem(value: id, child: Text(label));
                }).toList(),
                onChanged: (v) {
                  final y = years.firstWhere((y) => y['academicyearid'] == v);
                  setState(() {
                    _yearId = v;
                    _yearLabel = '${y['academicyear']} — ${y['term']}';
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
                  children: ['ALL', 'PENDING', 'APPROVED', 'RETAINED']
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
      error: (e, _) => Center(child: Text('Error: $e')),
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
    'APPROVED' => Colors.green,
    'RETAINED' => Colors.orange,
    'REJECTED' => Colors.red,
    _ => Colors.grey,
  };

  IconData _decisionIcon(String d) => switch (d) {
    'APPROVED' => Icons.check_circle,
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
    final actor = ref.read(authProvider).user!;
    final staffRow = await supabase
        .from('staff')
        .select('staffid')
        .eq('userid', actor.userId)
        .single();
    final staffId = staffRow['staffid'] as String;

    await ProgressionRepository().decide(
      reviewId: reviewId,
      staffId: staffId,
      decision: decision,
    );

    await AuditService().log(
      userId: actor.userId,
      action: 'PROGRESSION_DECISION',
      tableName: 'progressionreview',
      recordId: reviewId,
      actorRole: actor.roleName,
      newValue: {'decision': decision, 'student': studentName},
    );

    ref.invalidate(_progressionReviewsProvider(yearId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          tooltip: 'Approve',
          onPressed: () => _decide(context, ref, 'APPROVED'),
        ),
        IconButton(
          icon: const Icon(Icons.pause_circle, color: Colors.orange),
          tooltip: 'Retain',
          onPressed: () => _decide(context, ref, 'RETAINED'),
        ),
      ],
    );
  }
}
