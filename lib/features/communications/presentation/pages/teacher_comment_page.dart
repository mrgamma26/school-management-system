import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/communications_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/auth/permission_helper.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../students/domain/student.dart';
import '../../../students/data/student_repository.dart';
import '../../../../widgets/ui_kit.dart';

// Providers

final _tcYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

// Get teacher's classes for the current academic year
final _teacherClassesProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String userId, String yearId})
    >((ref, args) {
      return AcademicRepository().teacherClasses(
        userId: args.userId,
        academicYearId: args.yearId,
      );
    });

// Get all students for a specific class
final _classStudentsProvider =
    FutureProvider.family<List<Student>, ({String classId, String yearId})>((
      ref,
      args,
    ) {
      return StudentRepository().listStudentsForClass(
        classId: args.classId,
        academicYearId: args.yearId,
      );
    });

// For admin/headteacher: all students in academic year
final _allStudentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      yearId,
    ) async {
      // All students enrolled in the current year
      final rows = await supabase
          .from('studentclasshistory')
          .select(
            'student(studentid, firstname, lastname), class(classroomname)',
          )
          .eq('academicyearid', yearId)
          .isFilter('enddate', null);
      return List<Map<String, dynamic>>.from(rows as List);
    });

final _tcCommentProvider =
    FutureProvider.family<
      Map<String, dynamic>?,
      ({String staffId, String studentId, String academicYearId})
    >((ref, args) async {
      return CommunicationsRepository().getComment(
        staffId: args.staffId,
        studentId: args.studentId,
        academicYearId: args.academicYearId,
      );
    });

final _tcStaffIdProvider = FutureProvider<String>((ref) async {
  final uid = ref.watch(authProvider).user!.userId;
  final row = await supabase
      .from('staff')
      .select('staffid')
      .eq('userid', uid)
      .single();
  return row['staffid'] as String;
});

// Page

/// Teacher comments - one narrative comment per student per academic year.
/// Teachers write their own. Head Teacher / Admin reads all.
class TeacherCommentPage extends ConsumerStatefulWidget {
  const TeacherCommentPage({super.key});

  @override
  ConsumerState<TeacherCommentPage> createState() => _TeacherCommentPageState();
}

class _TeacherCommentPageState extends ConsumerState<TeacherCommentPage> {
  String? _yearId;
  String? _classId;

  bool get _canWrite {
    final permHelper = ref.watch(permissionHelperProvider);
    return permHelper.maybeWhen(
      data: (perm) => perm?.canWriteComments ?? false,
      orElse: () => false,
    );
  }

  bool get _isTeacher {
    final permHelper = ref.watch(permissionHelperProvider);
    return permHelper.maybeWhen(
      data: (perm) => perm?.role == UserRole.staff,
      orElse: () => false,
    );
  }

  bool get _isAdmin {
    final permHelper = ref.watch(permissionHelperProvider);
    return permHelper.maybeWhen(
      data: (perm) => perm?.isAdmin ?? false,
      orElse: () => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_tcYearsProvider);
    final staffAsync = ref.watch(_tcStaffIdProvider);
    final user = ref.watch(authProvider).user;

    return PageFrame(
      kicker: 'Assessments',
      title: 'Student Comments',
      subtitle: 'One narrative comment per student per academic year.',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: yearsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (years) => Column(
                children: [
                  DropdownButtonFormField<String>(
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
                    onChanged: (v) => setState(() {
                      _yearId = v;
                      _classId = null; // Reset class when year changes
                    }),
                  ),
                  // Class filter - only for teachers
                  if (_isTeacher && _yearId != null && user != null) ...[
                    const SizedBox(height: 12),
                    _TeacherClassFilter(
                      userId: user.userId,
                      yearId: _yearId!,
                      selectedClassId: _classId,
                      onClassChanged: (classId) =>
                          setState(() => _classId = classId),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: _yearId == null
                ? const Center(
                    child: Text(
                      'Select a year to view / write comments',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : staffAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('Staff profile error: $e')),
                    data: (staffId) => _StudentCommentList(
                      yearId: _yearId!,
                      classId: _classId,
                      staffId: staffId,
                      canWrite: _canWrite,
                      isTeacher: _isTeacher,
                      isAdmin: _isAdmin,
                      userId: user?.userId ?? '',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Teacher class filter widget

class _TeacherClassFilter extends ConsumerWidget {
  final String userId;
  final String yearId;
  final String? selectedClassId;
  final ValueChanged<String?> onClassChanged;

  const _TeacherClassFilter({
    required this.userId,
    required this.yearId,
    required this.selectedClassId,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(
      _teacherClassesProvider((userId: userId, yearId: yearId)),
    );

    return classesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading classes: $e'),
      data: (classes) => DropdownButtonFormField<String?>(
        initialValue: selectedClassId,
        decoration: const InputDecoration(
          labelText: 'Class (optional)',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.class_),
        ),
        hint: const Text('All your classes'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All your classes'),
          ),
          ...classes.map((c) {
            final classId = c['classid'] as String;
            final className = c['classroomname'] as String;
            return DropdownMenuItem<String?>(
              value: classId,
              child: Text(className),
            );
          }),
        ],
        onChanged: onClassChanged,
      ),
    );
  }
}

// Student comment list

class _StudentCommentList extends ConsumerWidget {
  final String yearId;
  final String? classId;
  final String staffId;
  final bool canWrite;
  final bool isTeacher;
  final bool isAdmin;
  final String userId;

  const _StudentCommentList({
    required this.yearId,
    required this.classId,
    required this.staffId,
    required this.canWrite,
    required this.isTeacher,
    required this.isAdmin,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For teachers: show students from their classes (filtered by classId if selected)
    if (isTeacher) {
      // If no class selected, get all teacher's classes and combine students
      if (classId == null) {
        return _AllTeacherStudentsView(
          userId: userId,
          yearId: yearId,
          staffId: staffId,
          canWrite: canWrite,
        );
      }

      // Single class selected
      final studentsAsync = ref.watch(
        _classStudentsProvider((classId: classId!, yearId: yearId)),
      );

      return _StudentCommentListView(
        studentsAsync: studentsAsync,
        staffId: staffId,
        yearId: yearId,
        canWrite: canWrite,
        onComment: (sid, sname, existing) =>
            _showCommentDialog(context, ref, sid, sname, existing),
      );
    }

    // For admin/headteacher: show all students
    final studentsAsync = ref.watch(_allStudentsProvider(yearId));
    return _StudentCommentListView(
      studentsAsync: studentsAsync,
      staffId: staffId,
      yearId: yearId,
      canWrite: canWrite,
      onComment: (sid, sname, existing) =>
          _showCommentDialog(context, ref, sid, sname, existing),
    );
  }

  Future<void> _showCommentDialog(
    BuildContext context,
    WidgetRef ref,
    String studentId,
    String studentName,
    String? existing,
  ) async {
    final ctrl = TextEditingController(text: existing ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Comment for $studentName'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comment',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await CommunicationsRepository().upsertComment(
                studentId: studentId,
                staffId: staffId,
                academicYearId: yearId,
                comment: ctrl.text.trim(),
              );
              final actor = ref.read(authProvider).user!;
              await AuditService().log(
                userId: actor.userId,
                action: existing != null
                    ? 'TEACHER_COMMENT_UPDATED'
                    : 'TEACHER_COMMENT_CREATED',
                tableName: 'teachercomment',
                recordId: studentId,
                actorRole: actor.roleName,
              );
              ref.invalidate(
                _tcCommentProvider((
                  staffId: staffId,
                  studentId: studentId,
                  academicYearId: yearId,
                )),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing != null ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }
}

// View all students from all teacher's classes
class _AllTeacherStudentsView extends ConsumerWidget {
  final String userId;
  final String yearId;
  final String staffId;
  final bool canWrite;

  const _AllTeacherStudentsView({
    required this.userId,
    required this.yearId,
    required this.staffId,
    required this.canWrite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(
      _teacherClassesProvider((userId: userId, yearId: yearId)),
    );

    return classesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading classes: $e')),
      data: (classes) {
        if (classes.isEmpty) {
          return const Center(
            child: Text(
              'No classes assigned for this teacher in this year.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: classes.length,
          itemBuilder: (context, i) {
            final classData = classes[i];
            final classId = classData['classid'] as String;
            final className = classData['classroomname'] as String;

            return ExpansionTile(
              title: Text(
                className,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                _ClassStudentsList(
                  classId: classId,
                  yearId: yearId,
                  staffId: staffId,
                  canWrite: canWrite,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Single class students list
class _ClassStudentsList extends ConsumerWidget {
  final String classId;
  final String yearId;
  final String staffId;
  final bool canWrite;

  const _ClassStudentsList({
    required this.classId,
    required this.yearId,
    required this.staffId,
    required this.canWrite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(
      _classStudentsProvider((classId: classId, yearId: yearId)),
    );

    return studentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e')),
      data: (students) {
        if (students.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No students in this class.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final student = students[i];
            final sid = student.studentId;
            final name = '${student.firstName} ${student.lastName}';
            final args = (
              staffId: staffId,
              studentId: sid,
              academicYearId: yearId,
            );
            final commentAsync = ref.watch(_tcCommentProvider(args));

            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  commentAsync.when(
                    loading: () => 'Loading...',
                    error: (_, _) => 'Error',
                    data: (c) => c != null
                        ? (c['comment'] as String).length > 60
                              ? '${(c['comment'] as String).substring(0, 60)}…'
                              : c['comment'] as String
                        : 'No comment yet',
                  ),
                ),
                trailing: canWrite
                    ? IconButton(
                        icon: Icon(
                          commentAsync.value != null
                              ? Icons.edit
                              : Icons.add_comment,
                          color: Colors.teal,
                        ),
                        onPressed: () => _showCommentDialog(
                          context,
                          ref,
                          sid,
                          name,
                          commentAsync.value?['comment'] as String?,
                        ),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCommentDialog(
    BuildContext context,
    WidgetRef ref,
    String studentId,
    String studentName,
    String? existing,
  ) async {
    final ctrl = TextEditingController(text: existing ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Comment for $studentName'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comment',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await CommunicationsRepository().upsertComment(
                studentId: studentId,
                staffId: staffId,
                academicYearId: yearId,
                comment: ctrl.text.trim(),
              );
              final actor = ref.read(authProvider).user!;
              await AuditService().log(
                userId: actor.userId,
                action: existing != null
                    ? 'TEACHER_COMMENT_UPDATED'
                    : 'TEACHER_COMMENT_CREATED',
                tableName: 'teachercomment',
                recordId: studentId,
                actorRole: actor.roleName,
              );
              ref.invalidate(
                _tcCommentProvider((
                  staffId: staffId,
                  studentId: studentId,
                  academicYearId: yearId,
                )),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing != null ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }
}

// Generic student comment list view
class _StudentCommentListView extends ConsumerWidget {
  final AsyncValue<dynamic> studentsAsync;
  final String staffId;
  final String yearId;
  final bool canWrite;
  final Function(String, String, String?) onComment;

  const _StudentCommentListView({
    required this.studentsAsync,
    required this.staffId,
    required this.yearId,
    required this.canWrite,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        List<dynamic> students = [];

        // Handle both Student objects and raw map rows
        if (data is List<Student>) {
          students = data;
        } else if (data is List<Map<String, dynamic>>) {
          students = data;
        }

        if (students.isEmpty) {
          return const Center(
            child: Text(
              'No students found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: students.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final item = students[i];
            late String sid;
            late String name;

            if (item is Student) {
              sid = item.studentId;
              name = '${item.firstName} ${item.lastName}';
            } else if (item is Map<String, dynamic>) {
              final student = item['student'] as Map<String, dynamic>;
              sid = student['studentid'] as String;
              name = '${student['firstname']} ${student['lastname']}';
            } else {
              return const SizedBox();
            }

            final args = (
              staffId: staffId,
              studentId: sid,
              academicYearId: yearId,
            );
            final commentAsync = ref.watch(_tcCommentProvider(args));

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  commentAsync.when(
                    loading: () => 'Loading...',
                    error: (_, _) => 'Error',
                    data: (c) => c != null
                        ? (c['comment'] as String).length > 60
                              ? '${(c['comment'] as String).substring(0, 60)}…'
                              : c['comment'] as String
                        : 'No comment yet',
                  ),
                ),
                trailing: canWrite
                    ? IconButton(
                        icon: Icon(
                          commentAsync.value != null
                              ? Icons.edit
                              : Icons.add_comment,
                          color: Colors.teal,
                        ),
                        onPressed: () => onComment(
                          sid,
                          name,
                          commentAsync.value?['comment'] as String?,
                        ),
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
