import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/can.dart';
import '../../../../core/auth/permission_helper.dart';
import '../../data/assessment_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Loads all teacher assignments whose class and academic-period forms match.
/// Historical terms remain available for authorised corrections and reviews.
final _formMatchedAssignmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      staffId,
    ) async {
      final rows = await supabase
          .from('classsubject')
          .select(
            'classsubjectid, class(classroomname, form), subject(subjectname), '
            'academicyear(academicyearid, academicyear, term, form, startdate, enddate)',
          )
          .eq('staffid', staffId);
      return List<Map<String, dynamic>>.from(rows as List).where((row) {
        final period = row['academicyear'] as Map?;
        final classroom = row['class'] as Map?;
        if (period == null || classroom == null) return false;
        final periodForm = period['form']?.toString();
        final classForm = classroom['form']?.toString();
        if (periodForm == null || periodForm != classForm) return false;
        return true;
      }).toList();
    });

final _staffIdProvider = FutureProvider<String>((ref) async {
  final uid = ref.watch(authProvider).user!.userId;
  final row = await supabase
      .from('staff')
      .select('staffid')
      .eq('userid', uid)
      .single();
  return row['staffid'] as String;
});

/// Used only for the page-level empty state. Assignment visibility itself is
/// resolved per form by [_formMatchedAssignmentsProvider].
final _activeYearProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final row = await supabase
      .from('academicyear')
      .select('academicyearid')
      .not('form', 'is', null)
      .lte('startdate', today)
      .gte('enddate', today)
      .limit(1)
      .maybeSingle();
  return row == null ? null : Map<String, dynamic>.from(row);
});

final _assessmentsForCsProvider =
    FutureProvider.family<List<Assessment>, String>((ref, csId) async {
      return AssessmentRepository().listForClassSubject(csId);
    });

// ── Page ──────────────────────────────────────────────────────────────────────

/// Lists a teacher's class-subject assignments for a chosen academic year,
/// then lets them drill into assessments for each assignment.
class AssessmentsPage extends ConsumerStatefulWidget {
  const AssessmentsPage({super.key});

  @override
  ConsumerState<AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends ConsumerState<AssessmentsPage> {
  // Kept only for the hidden legacy picker below while existing widget state is
  // migrated. Teachers use the active year automatically.
  String? _selectedYearId;

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(_staffIdProvider);
    final activeYearAsync = ref.watch(_activeYearProvider);
    final permHelper = ref.watch(permissionHelperProvider);
    final canManageAssessments = permHelper.maybeWhen(
      data: (perm) => perm?.canManageAssessments ?? false,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Assessments & Grades')),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Could not load your staff profile: $e')),
        data: (staffId) => activeYearAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Could not load the active year: $e')),
          data: (year) {
            if (year == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'There is no active academic year. Ask an administrator to set its dates.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final years = [year];
            final yearId = year['academicyearid'] as String;
            return Column(
              children: [
                // ── Year picker ────────────────────────────────────────────────
                if (_selectedYearId != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedYearId,
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
                        setState(() {
                          _selectedYearId = v;
                        });
                      },
                    ),
                  ),

                // ── Assignment list ────────────────────────────────────────────
                Expanded(
                  child: _AssignmentList(
                    staffId: staffId,
                    yearId: yearId,
                    yearLabel: 'Current year',
                    canManage:
                        canManageAssessments ||
                        ref.read(authProvider).user?.roleName.toUpperCase() ==
                            'TEACHER',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Assignment list ───────────────────────────────────────────────────────────

class _AssignmentList extends ConsumerWidget {
  final String staffId;
  final String yearId;
  final String yearLabel;
  final bool canManage;

  const _AssignmentList({
    required this.staffId,
    required this.yearId,
    required this.yearLabel,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_formMatchedAssignmentsProvider(staffId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assignments) {
        if (assignments.isEmpty) {
          return const Center(
            child: Text(
              'No class assignments match a form-specific academic period.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: assignments.length,
          itemBuilder: (context, i) {
            final a = assignments[i];
            final csId = a['classsubjectid'] as String;
            final className = (a['class'] as Map?)?['classroomname'] ?? '—';
            final subName = (a['subject'] as Map?)?['subjectname'] ?? '—';
            final period = a['academicyear'] as Map?;
            final periodLabel = period == null
                ? 'Academic period'
                : '${period['academicyear']}/${(period['academicyear'] as int) + 1} • ${period['term'].toString().replaceAll('_', ' ')}';

            return Card(
              child: ExpansionTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.book, color: Colors.white, size: 20),
                ),
                title: Text(
                  subName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Class: $className • $periodLabel'),
                children: [
                  _AssessmentSubList(
                    classSubjectId: csId,
                    className: className,
                    subjectName: subName,
                    canManage: canManage,
                    canEnterGrades: ref
                        .watch(permissionHelperProvider)
                        .maybeWhen(
                          data: (permissions) =>
                              permissions?.canEnterGrades ?? false,
                          orElse: () => false,
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Assessment sub-list ───────────────────────────────────────────────────────

class _AssessmentSubList extends ConsumerWidget {
  final String classSubjectId;
  final String className;
  final String subjectName;
  final bool canManage;
  final bool canEnterGrades;

  const _AssessmentSubList({
    required this.classSubjectId,
    required this.className,
    required this.subjectName,
    required this.canManage,
    required this.canEnterGrades,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_assessmentsForCsProvider(classSubjectId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error loading assessments: $e'),
      ),
      data: (assessments) => Column(
        children: [
          ...assessments.map(
            (a) => ListTile(
              leading: Icon(_typeIcon(a.type), color: _typeColor(a.type)),
              title: Text(a.name),
              subtitle: Text('${a.type} • Max: ${a.maxScore}'),
              trailing: canEnterGrades
                  ? IconButton(
                      icon: const Icon(Icons.grade, color: Colors.orange),
                      tooltip: 'Enter Grades',
                      onPressed: () => context.go(
                        '/assessments/${a.id}/grades',
                        extra: {
                          'maxScore': a.maxScore,
                          'assessmentName': a.name,
                          'classSubjectId': classSubjectId,
                        },
                      ),
                    )
                  : null,
            ),
          ),
          if (canManage)
            Can(
              permission: 'assessments:write',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: OutlinedButton.icon(
                  onPressed: () => _showAddDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Assessment'),
                ),
              ),
            ),
          if (assessments.isEmpty && !canManage)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No assessments yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();
    String selectedType = 'TEST';
    bool saving = false;
    String? error;
    Assessment? createdAssessment;
    const types = [
      'QUIZ',
      'TEST',
      'EXAM',
      'ASSIGNMENT',
      'PROJECT',
      'PRACTICAL',
      'END_OF_TERM',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Assessment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assessment Name *',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: types
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSt(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Score *'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final score = double.tryParse(scoreCtrl.text.trim()) ?? 0;
                      if (name.isEmpty || score <= 0) {
                        setSt(
                          () => error =
                              'Enter an assessment name and maximum score.',
                        );
                        return;
                      }
                      setSt(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        createdAssessment = await AssessmentRepository()
                            .createAssessment(
                              classSubjectId: classSubjectId,
                              name: name,
                              type: selectedType,
                              maxScore: score,
                            );
                        ref.invalidate(
                          _assessmentsForCsProvider(classSubjectId),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        setSt(
                          () => error =
                              'Could not create the assessment. Please try again.',
                        );
                      } finally {
                        if (ctx.mounted) setSt(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Creating…' : 'Add'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    scoreCtrl.dispose();
    if (createdAssessment != null && context.mounted) {
      context.go(
        '/assessments/${createdAssessment!.id}/grades',
        extra: {
          'maxScore': createdAssessment!.maxScore,
          'assessmentName': createdAssessment!.name,
          'classSubjectId': classSubjectId,
        },
      );
    }
  }

  IconData _typeIcon(String type) => switch (type) {
    'EXAM' => Icons.description,
    'QUIZ' => Icons.help_outline,
    'ASSIGNMENT' => Icons.assignment,
    'PROJECT' => Icons.science,
    'PRACTICAL' => Icons.biotech,
    'END_OF_TERM' => Icons.event_available,
    _ => Icons.quiz,
  };

  Color _typeColor(String type) => switch (type) {
    'EXAM' => Colors.red,
    'QUIZ' => Colors.orange,
    'ASSIGNMENT' => Colors.blue,
    'PROJECT' => Colors.purple,
    'PRACTICAL' => Colors.teal,
    'END_OF_TERM' => Colors.indigo,
    _ => Colors.grey,
  };
}
