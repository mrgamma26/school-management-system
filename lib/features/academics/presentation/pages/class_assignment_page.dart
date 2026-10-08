import 'package:school_management_app/features/academics/domain/models/academic_year.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/class_subject.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../widgets/skeleton_loader.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _assignmentYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term, form')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

/// Scoped provider: Teachers see only their own assignments.
/// Admins/Super Users see all assignments.
final _assignmentsProvider =
    FutureProvider.family<
      List<ClassSubject>,
      ({String yearId, String? userId, String? roleName})
    >((ref, args) async {
      // If roleName is TEACHER and userId is provided, scope to that teacher
      if (args.roleName?.toUpperCase() == 'TEACHER' && args.userId != null) {
        final staff = await supabase
            .from('staff')
            .select('staffid')
            .eq('userid', args.userId!)
            .maybeSingle();
        final staffId = staff?['staffid'] as String?;
        if (staffId == null) return const [];
        return AcademicRepository().teacherAssignments(staffId, args.yearId);
      }
      // Admins/Super Users see all assignments
      return AcademicRepository().listAssignments(args.yearId);
    });

final _allClassesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('class')
      .select('classid, classroomname, form')
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

/// Active Teacher users who have a linked staff profile. Role and active-state
/// filtering happen before staff records reach either assignment dropdown.
final _teachersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final teacherRole = await supabase
      .from('role')
      .select('roleid')
      .eq('rolename', 'TEACHER')
      .maybeSingle();
  final teacherRoleId = teacherRole?['roleid'] as String?;
  if (teacherRoleId == null) return const [];

  final teacherUsers = List<Map<String, dynamic>>.from(
    await supabase
        .from('systemuser')
        .select('userid')
        .eq('roleid', teacherRoleId)
        .eq('isactive', true),
  );
  final teacherUserIds = teacherUsers
      .map((user) => user['userid'] as String)
      .toList();
  if (teacherUserIds.isEmpty) return const [];

  final rows = await supabase
      .from('staff')
      .select('staffid, userid, firstname, lastname')
      .inFilter('userid', teacherUserIds)
      .order('lastname');
  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Page ──────────────────────────────────────────────────────────────────────

class _TeacherClassGroup {
  final String classId;
  final String className;
  final String academicYearId;
  final String academicYearLabel;
  final List<String> subjects;

  const _TeacherClassGroup({
    required this.classId,
    required this.className,
    required this.academicYearId,
    required this.academicYearLabel,
    required this.subjects,
  });
}

final _teacherClassGroupsProvider =
    FutureProvider.family<List<_TeacherClassGroup>, String>((
      ref,
      userId,
    ) async {
      final assignments = await AcademicRepository().teacherAssignmentsForUser(
        userId,
      );
      if (assignments.isEmpty) return const [];

      final yearRows = List<Map<String, dynamic>>.from(
        await supabase
            .from('academicyear')
            .select('academicyearid, academicyear, term, form')
            .order('academicyear', ascending: false),
      );
      final yearLabels = {
        for (final year in yearRows)
          year['academicyearid'] as String:
              '${formatAcademicYear(year['academicyear'])} • ${formatFormLevel(year['form']?.toString())} • ${year['term'].toString().replaceAll('_', ' ')}',
      };

      final grouped = <String, _TeacherClassGroup>{};
      for (final assignment in assignments) {
        final key = '${assignment.academicYearId}:${assignment.classId}';
        final existing = grouped[key];
        final subject = assignment.subjectName ?? 'Subject';
        if (existing == null) {
          grouped[key] = _TeacherClassGroup(
            classId: assignment.classId,
            className: assignment.className ?? 'Class',
            academicYearId: assignment.academicYearId,
            academicYearLabel:
                yearLabels[assignment.academicYearId] ?? 'Academic year',
            subjects: [subject],
          );
        } else if (!existing.subjects.contains(subject)) {
          grouped[key] = _TeacherClassGroup(
            classId: existing.classId,
            className: existing.className,
            academicYearId: existing.academicYearId,
            academicYearLabel: existing.academicYearLabel,
            subjects: [...existing.subjects, subject],
          );
        }
      }

      final groups = grouped.values.toList()
        ..sort((a, b) {
          final yearComparison = b.academicYearLabel.compareTo(
            a.academicYearLabel,
          );
          return yearComparison != 0
              ? yearComparison
              : a.className.compareTo(b.className);
        });
      return groups;
    });

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
  String? _yearForm;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final roleName = user?.roleName.trim().toUpperCase();
    final isTeacher = roleName == 'TEACHER';

    if (isTeacher) {
      return Scaffold(
        appBar: AppBar(title: const Text('Classes You Teach')),
        body: user == null
            ? const Center(child: Text('Please sign in again to view classes.'))
            : _TeacherClassesView(userId: user.userId),
      );
    }

    final yearsAsync = ref.watch(_assignmentYearsProvider);

    final canManage = const {
      'SUPER_USER',
      'SYSTEM_ADMIN',
      'ADMINISTRATOR',
      'ADMIN',
    }.contains(roleName);

    return Scaffold(
      appBar: AppBar(title: const Text('Class Assignments')),
      floatingActionButton: (_yearId != null && _yearForm != null && canManage)
          ? FloatingActionButton.extended(
              onPressed: _showAssignDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Teacher to Subject'),
            )
          : null,
      body: yearsAsync.when(
        loading: () => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SkeletonFormField(height: 56),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: 5,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SkeletonCard(
                    height: 80,
                    padding: const EdgeInsets.all(0),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                  final label =
                      '${formatAcademicYear(y['academicyear'])} • ${formatFormLevel(y['form']?.toString())} • ${y['term'].toString().replaceAll('_', ' ')}';
                  return DropdownMenuItem(value: id, child: Text(label));
                }).toList(),
                onChanged: (v) {
                  final selected = years.firstWhere(
                    (year) => year['academicyearid'] == v,
                  );
                  setState(() {
                    _yearId = v;
                    _yearForm = selected['form']?.toString();
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
                  : _AssignmentList(
                      yearId: _yearId!,
                      canManage: canManage,
                      userId: user?.userId,
                      roleName: user?.roleName,
                    ),
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

    // Invalidate before showing dialog to avoid state changes during build
    ref.invalidate(_allSubjectsProvider);

    await showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final classesAsync = ref.watch(_allClassesProvider);
          final subjectsAsync = ref.watch(_allSubjectsProvider);
          final staffListAsync = ref.watch(_teachersProvider);

          return AlertDialog(
            title: const Text('Add Class Assignment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Class
                  classesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (classes) {
                      final matchingClasses = classes
                          .where((c) => c['form']?.toString() == _yearForm)
                          .toList();
                      if (matchingClasses.isEmpty) {
                        return Text(
                          'No ${formatFormLevel(_yearForm)} classes are configured.',
                          style: const TextStyle(color: Colors.red),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          border: OutlineInputBorder(),
                        ),
                        items: matchingClasses
                            .map(
                              (c) => DropdownMenuItem(
                                value: c['classid'] as String,
                                child: Text(c['classroomname'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => classId = v,
                      );
                    },
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
                    data: (staff) {
                      if (staff.isEmpty) {
                        return const Text(
                          'No active users with the Teacher role are available.',
                          style: TextStyle(color: Colors.red),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Teacher',
                          border: OutlineInputBorder(),
                        ),
                        items: staff
                            .map(
                              (s) => DropdownMenuItem(
                                value: s['staffid'] as String,
                                child: Text(
                                  '${s['firstname']} ${s['lastname']}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => staffId = v,
                      );
                    },
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
                  try {
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
                  } catch (error) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('Could not save assignment: $error'),
                        ),
                      );
                    }
                    return;
                  }

                  final user = ref.read(authProvider).user!;
                  // Invalidate assignments provider to refresh the list
                  ref.invalidate(
                    _assignmentsProvider((
                      yearId: _yearId!,
                      userId: user.userId,
                      roleName: user.roleName,
                    )),
                  );
                  // Also invalidate subjects provider in case it was updated
                  ref.invalidate(_allSubjectsProvider);
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

class _TeacherClassesView extends ConsumerWidget {
  final String userId;

  const _TeacherClassesView({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(_teacherClassGroupsProvider(userId));

    return groups.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 3,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: SkeletonCard(height: 152, padding: EdgeInsets.zero),
        ),
      ),
      error: (_, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Your classes could not be loaded. Please try again.'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'You have not been assigned to any classes yet. Please ask an administrator to add your class assignments.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final group = items[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.className,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Academic year: ${group.academicYearLabel}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.subjects
                          .map((subject) => Chip(label: Text(subject)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/teacher/classes/${group.classId}/students/${group.academicYearId}'
                          '?className=${Uri.encodeComponent(group.className)}'
                          '&year=${Uri.encodeComponent(group.academicYearLabel)}',
                        ),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('View Students'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AssignmentList extends ConsumerWidget {
  final String yearId;
  final bool canManage;
  final String? userId;
  final String? roleName;

  const _AssignmentList({
    required this.yearId,
    required this.canManage,
    required this.userId,
    required this.roleName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      _assignmentsProvider((
        yearId: yearId,
        userId: userId,
        roleName: roleName,
      )),
    );

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
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.blueGrey,
                            ),
                            tooltip: 'Edit Assignment',
                            onPressed: () => _showEditDialog(context, ref, a),
                          ),
                          IconButton(
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
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
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
                              ref.invalidate(
                                _assignmentsProvider((
                                  yearId: yearId,
                                  userId: userId,
                                  roleName: roleName,
                                )),
                              );
                            },
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ClassSubject assignment,
  ) async {
    String? newStaffId = assignment.staffId;

    await showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final staffListAsync = ref.watch(_teachersProvider);

          return AlertDialog(
            title: const Text('Edit Assignment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class: ${assignment.className}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subject: ${assignment.subjectName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Change Teacher:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                staffListAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (staff) {
                    if (staff.isEmpty) {
                      return const Text(
                        'No active users with the Teacher role are available.',
                        style: TextStyle(color: Colors.red),
                      );
                    }
                    final selectableValue =
                        staff.any((teacher) => teacher['staffid'] == newStaffId)
                        ? newStaffId
                        : null;
                    return DropdownButtonFormField<String>(
                      initialValue: selectableValue,
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
                      onChanged: (v) => newStaffId = v,
                    );
                  },
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
                  if (newStaffId == null || newStaffId == assignment.staffId) {
                    Navigator.pop(ctx);
                    return;
                  }

                  // Update the assignment
                  await AcademicRepository().updateAssignment(
                    assignmentId: assignment.id,
                    newStaffId: newStaffId!,
                  );

                  final actor = ref.read(authProvider).user!;
                  await AuditService().log(
                    userId: actor.userId,
                    action: 'TEACHER_ASSIGNMENT_UPDATED',
                    tableName: 'classsubject',
                    recordId: assignment.id,
                    actorRole: actor.roleName,
                    previousValue: {'staffId': assignment.staffId},
                    newValue: {'staffId': newStaffId},
                  );

                  ref.invalidate(
                    _assignmentsProvider((
                      yearId: yearId,
                      userId: userId,
                      roleName: roleName,
                    )),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }
}
