import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/assessment_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Loads all classsubject rows for a staff member in a given academic year,
/// joined with class and subject names.
final _myAssignmentsProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String staffId, String yearId})
    >((ref, args) async {
      final rows = await supabase
          .from('classsubject')
          .select('classsubjectid, class(classroomname), subject(subjectname)')
          .eq('staffid', args.staffId)
          .eq('academicyearid', args.yearId);
      return List<Map<String, dynamic>>.from(rows as List);
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

final _yearsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
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
  String? _selectedYearId;
  String? _selectedYearLabel;

  bool get _canManage {
    final r = ref.read(authProvider).user?.roleName.toUpperCase() ?? '';
    return r == 'TEACHER' || r == 'SYSTEM_ADMIN' || r == 'SUPER_USER';
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(_staffIdProvider);
    final yearsAsync = ref.watch(_yearsProvider);
    final role = ref.watch(authProvider).user?.roleName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessments'),
        actions: [HomeButton(roleName: role)],
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Could not load your staff profile: $e')),
        data: (staffId) => yearsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Could not load academic years: $e')),
          data: (years) => Column(
            children: [
              // ── Year picker ────────────────────────────────────────────────
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
                    final y = years.firstWhere((y) => y['academicyearid'] == v);
                    setState(() {
                      _selectedYearId = v;
                      _selectedYearLabel =
                          '${y['academicyear']} — ${y['term']}';
                    });
                  },
                ),
              ),

              // ── Assignment list ────────────────────────────────────────────
              Expanded(
                child: _selectedYearId == null
                    ? const Center(
                        child: Text(
                          'Select an academic year to view your assignments',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : _AssignmentList(
                        staffId: staffId,
                        yearId: _selectedYearId!,
                        yearLabel: _selectedYearLabel!,
                        canManage: _canManage,
                      ),
              ),
            ],
          ),
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
    final args = (staffId: staffId, yearId: yearId);
    final async = ref.watch(_myAssignmentsProvider(args));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assignments) {
        if (assignments.isEmpty) {
          return const Center(
            child: Text(
              'No class assignments found for this year.',
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
                subtitle: Text('Class: $className'),
                children: [
                  _AssessmentSubList(
                    classSubjectId: csId,
                    className: className,
                    subjectName: subName,
                    canManage: canManage,
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

  const _AssessmentSubList({
    required this.classSubjectId,
    required this.className,
    required this.subjectName,
    required this.canManage,
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
              trailing: canManage
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Assessment'),
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
    const types = [
      'QUIZ',
      'TEST',
      'EXAM',
      'ASSIGNMENT',
      'PROJECT',
      'PRACTICAL',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Assessment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final score = double.tryParse(scoreCtrl.text.trim()) ?? 0;
                if (name.isEmpty || score <= 0) return;
                await AssessmentRepository().createAssessment(
                  classSubjectId: classSubjectId,
                  name: name,
                  type: selectedType,
                  maxScore: score,
                );
                ref.invalidate(_assessmentsForCsProvider(classSubjectId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    scoreCtrl.dispose();
  }

  IconData _typeIcon(String type) => switch (type) {
    'EXAM' => Icons.description,
    'QUIZ' => Icons.help_outline,
    'ASSIGNMENT' => Icons.assignment,
    'PROJECT' => Icons.science,
    'PRACTICAL' => Icons.biotech,
    _ => Icons.quiz,
  };

  Color _typeColor(String type) => switch (type) {
    'EXAM' => Colors.red,
    'QUIZ' => Colors.orange,
    'ASSIGNMENT' => Colors.blue,
    'PROJECT' => Colors.purple,
    'PRACTICAL' => Colors.teal,
    _ => Colors.grey,
  };
}
