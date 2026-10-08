import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/weeding_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/auth/permission_helper.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// Providers

final _weedingYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
      .order('academicyear', ascending: false);
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
      data: (perm) => perm?.canDecideWeeding ?? false,
      orElse: () => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_weedingYearsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weeding Reviews'),
        actions: [
          if (_yearId != null && _canDecide)
            TextButton.icon(
              onPressed: () => _showFlagDialog(),
              icon: const Icon(Icons.flag),
              label: const Text('Flag Student'),
            ),
        ],
      ),
      body: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (years) => Column(
          children: [
            // Year selector
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
                  final label = '${y['academicyear']} - ${y['term']}';
                  return DropdownMenuItem(value: id, child: Text(label));
                }).toList(),
                onChanged: (v) => setState(() => _yearId = v),
              ),
            ),

            // Filter chips
            if (_yearId != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: ['ALL', 'PENDING', 'WEED_OUT', 'RETAIN']
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

            // List
            Expanded(
              child: _yearId == null
                  ? const Center(
                      child: Text(
                        'Select a year to view weeding reviews',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _WeedingList(
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

  Future<void> _showFlagDialog() async {
    final sidCtrl = TextEditingController();
    final avgCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flag Student for Weeding'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will flag a student for a weeding review.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sidCtrl,
              decoration: const InputDecoration(labelText: 'Student ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avgCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cumulative Average (0-100)',
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final sid = sidCtrl.text.trim();
              final avg = double.tryParse(avgCtrl.text.trim()) ?? -1;
              if (sid.isEmpty || avg < 0 || avg > 100) return;
              await WeedingRepository().flagStudent(
                studentId: sid,
                academicYearId: _yearId!,
                cumulativeAverage: avg,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Flag'),
          ),
        ],
      ),
    );
    sidCtrl.dispose();
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (reviews) {
        final filtered = filter == 'ALL'
            ? reviews
            : reviews.where((r) => r['decision'] == filter).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              filter == 'PENDING'
                  ? 'No pending weeding reviews.'
                  : 'No $filter reviews found.',
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
            final avg = r['cumulativeaverage'];
            final reason = r['decisionreason'] as String?;
            final decider = r['staff'] as Map<String, dynamic>?;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _color(decision),
                  child: Icon(_icon(decision), color: Colors.white, size: 20),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cumulative Average: ${avg ?? '-'}'),
                    Text('Flagged: ${r['flaggeddate'] ?? '-'}'),
                    if (reason != null && reason.isNotEmpty)
                      Text(
                        'Reason: $reason',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    if (decider != null)
                      Text(
                        'By: ${decider['firstname']} ${decider['lastname']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                isThreeLine: true,
                trailing: decision == 'PENDING' && canDecide
                    ? _WeedButtons(
                        weedingId: r['weedingid'] as String,
                        yearId: yearId,
                        studentName: name,
                      )
                    : Chip(
                        label: Text(decision),
                        backgroundColor: _color(
                          decision,
                        ).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _color(decision),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Color _color(String d) => switch (d) {
    'WEED_OUT' => Colors.red,
    'RETAIN' => Colors.green,
    _ => Colors.orange,
  };

  IconData _icon(String d) => switch (d) {
    'WEED_OUT' => Icons.remove_circle,
    'RETAIN' => Icons.check_circle,
    _ => Icons.hourglass_empty,
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

    await WeedingRepository().decide(
      weedingId: weedingId,
      staffId: staffId,
      decision: decision,
      reason: reason,
    );

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
