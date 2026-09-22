import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/class_subject.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _assignmentYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

final _assignmentsProvider = FutureProvider.family<List<ClassSubject>, String>((
  ref,
  yearId,
) async {
  return AcademicRepository().listAssignments(yearId);
});

final _allClassesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('class')
      .select('classid, classroomname')
      .order('classroomname');
  return List<Map<String, dynamic>>.from(rows as List);
});

final _allSubjectsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('subject')
      .select('subjectid, subjectname')
      .order('subjectname');
  return List<Map<String, dynamic>>.from(rows as List);
});

final _allStaffProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('staff')
      .select('staffid, firstname, lastname')
      .order('lastname');
  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// View and manage teacher-class-subject assignments (classsubject table).
/// Administrators and Super Users can assign/remove teachers.
/// Teachers can view their own assignments.
class ClassAssignmentPage extends ConsumerStatefulWidget {
  const ClassAssignmentPage({super.key});

  @override
  ConsumerState<ClassAssignmentPage> createState() =>
      _ClassAssignmentPageState();
}

class _ClassAssignmentPageState extends ConsumerState<ClassAssignmentPage> {
  String? _yearId;
  String? _yearLabel;

  bool get _canManage {
    final r = ref.read(authProvider).user?.roleName.toUpperCase() ?? '';
    return r == 'SYSTEM_ADMIN' ||
        r == 'SUPER_USER' ||
        r == 'ADMINISTRATOR' ||
        r == 'REGISTRAR';
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_assignmentYearsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Assignments'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          if (_yearId != null && _canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Assign Teacher',
              onPressed: () => _showAssignDialog(),
            ),
        ],
      ),
      body: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (years) => Column(
          children: [
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
            Expanded(
              child: _yearId == null
                  ? const Center(
                      child: Text(
                        'Select a year to view assignments',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _AssignmentList(yearId: _yearId!, canManage: _canManage),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignDialog() async {
    String? classId;
    String? subjectId;
    String? staffId;

    await showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final classesAsync = ref.watch(_allClassesProvider);
          final subjectsAsync = ref.watch(_allSubjectsProvider);
          final staffListAsync = ref.watch(_allStaffProvider);

          return AlertDialog(
            title: const Text('Assign Teacher'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Class
                  classesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (classes) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      items: classes
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['classid'] as String,
                              child: Text(c['classroomname'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => classId = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Subject
                  subjectsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (subjects) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                      items: subjects
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['subjectid'] as String,
                              child: Text(s['subjectname'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => subjectId = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Teacher
                  staffListAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (staff) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Teacher',
                        border: OutlineInputBorder(),
                      ),
                      items: staff
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['staffid'] as String,
                              child: Text('${s['firstname']} ${s['lastname']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => staffId = v,
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
                onPressed: () async {
                  if (classId == null || subjectId == null || staffId == null) {
                    return;
                  }

                  await AcademicRepository().assignTeacher(
                    classId: classId!,
                    subjectId: subjectId!,
                    staffId: staffId!,
                    academicYearId: _yearId!,
                  );

                  final actor = ref.read(authProvider).user!;
                  await AuditService().log(
                    userId: actor.userId,
                    action: 'TEACHER_ASSIGNED',
                    tableName: 'classsubject',
                    actorRole: actor.roleName,
                    newValue: {
                      'classId': classId,
                      'subjectId': subjectId,
                      'staffId': staffId,
                      'yearId': _yearId,
                    },
                  );

                  ref.invalidate(_assignmentsProvider(_yearId!));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Assign'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Assignment list ───────────────────────────────────────────────────────────

class _AssignmentList extends ConsumerWidget {
  final String yearId;
  final bool canManage;

  const _AssignmentList({required this.yearId, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_assignmentsProvider(yearId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assignments) {
        if (assignments.isEmpty) {
          return const Center(
            child: Text(
              'No assignments for this year yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: assignments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = assignments[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(
                    Icons.assignment_ind,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  '${a.subjectName} — ${a.className}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Teacher: ${a.staffName ?? '—'}'),
                trailing: canManage
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'Remove Assignment',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Remove Assignment'),
                              content: Text(
                                'Remove ${a.staffName ?? 'teacher'} from '
                                '${a.subjectName} in ${a.className}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          await AcademicRepository().removeAssignment(a.id);
                          final actor = ref.read(authProvider).user!;
                          await AuditService().log(
                            userId: actor.userId,
                            action: 'TEACHER_UNASSIGNED',
                            tableName: 'classsubject',
                            recordId: a.id,
                            actorRole: actor.roleName,
                          );
                          ref.invalidate(_assignmentsProvider(yearId));
                        },
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
