import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../academics/data/academic_repository.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../data/student_repository.dart';
import '../domain/student.dart';

final _teacherClassRosterProvider =
    FutureProvider.family<
      List<Student>,
      ({String userId, String classId, String yearId})
    >((ref, args) async {
      final assignments = await AcademicRepository().teacherAssignmentsForUser(
        args.userId,
      );
      final mayViewRoster = assignments.any(
        (assignment) =>
            assignment.classId == args.classId &&
            assignment.academicYearId == args.yearId,
      );
      if (!mayViewRoster) {
        throw StateError('This class is not assigned to you.');
      }

      return StudentRepository().listStudentsForClass(
        classId: args.classId,
        academicYearId: args.yearId,
      );
    });

/// Read-only roster for one class a teacher has been assigned to teach.
class TeacherClassStudentsPage extends ConsumerWidget {
  final String classId;
  final String academicYearId;
  final String className;
  final String academicYearLabel;

  const TeacherClassStudentsPage({
    required this.classId,
    required this.academicYearId,
    required this.className,
    required this.academicYearLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isTeacher = user?.roleName.trim().toUpperCase() == 'TEACHER';

    return Scaffold(
      appBar: AppBar(title: const Text('Class Students')),
      body: !isTeacher || user == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This student list is available to the assigned teacher only.',
                ),
              ),
            )
          : _RosterBody(
              userId: user.userId,
              classId: classId,
              academicYearId: academicYearId,
              className: className,
              academicYearLabel: academicYearLabel,
            ),
    );
  }
}

class _RosterBody extends ConsumerWidget {
  final String userId;
  final String classId;
  final String academicYearId;
  final String className;
  final String academicYearLabel;

  const _RosterBody({
    required this.userId,
    required this.classId,
    required this.academicYearId,
    required this.className,
    required this.academicYearLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(
      _teacherClassRosterProvider((
        userId: userId,
        classId: classId,
        yearId: academicYearId,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(className, style: Theme.of(context).textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Academic year: $academicYearLabel'),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: students.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'The student list could not be loaded. Please return to your classes and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('No active students are enrolled in this class.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final student = items[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(student.fullName),
                      subtitle: Text('Student ID: ${student.studentId}'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
