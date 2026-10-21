import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart' show LoadingState;
import '../../../widgets/ui_kit.dart';
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

    return PageFrame(
      kicker: 'Classes',
      title: className,
      subtitle: 'Academic year: $academicYearLabel',
      body: !isTeacher || user == null
          ? const UiCard(
              child: UiEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Assigned teacher only',
                message:
                    'This student list is available to the assigned teacher only.',
              ),
            )
          : _RosterBody(
              userId: user.userId,
              classId: classId,
              academicYearId: academicYearId,
            ),
    );
  }
}

class _RosterBody extends ConsumerWidget {
  final String userId;
  final String classId;
  final String academicYearId;

  const _RosterBody({
    required this.userId,
    required this.classId,
    required this.academicYearId,
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

    return students.when(
      loading: () => const LoadingState(message: 'Loading students…'),
      error: (_, _) => const UiCard(
        child: UiEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'The student list could not be loaded',
          message: 'Please return to your classes and try again.',
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const UiCard(
            child: UiEmptyState(
              icon: Icons.groups_outlined,
              title: 'No active students are enrolled in this class',
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: DataTableCard(
            columns: const [
              UiColumn('#', width: 36),
              UiColumn('Student', flex: 16),
              UiColumn('Student ID', flex: 12, hideOnPhone: true),
            ],
            rows: [
              for (var i = 0; i < items.length; i++)
                UiTableRow([
                  UiCellText('${i + 1}'),
                  PersonCell(items[i].fullName),
                  UiCellText(items[i].studentId),
                ]),
            ],
          ),
        );
      },
    );
  }
}
