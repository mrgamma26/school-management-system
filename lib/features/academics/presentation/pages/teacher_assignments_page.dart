import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';
import '../../data/academic_setup_repository.dart';

final academicSetupRepositoryProvider = Provider<AcademicSetupRepository>(
  (ref) => AcademicSetupRepository(),
);

final classesTaughtProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(academicSetupRepositoryProvider);
  final results = await Future.wait([
    repository.assignments(),
    repository.currentAcademicYear(),
  ]);
  return (
    assignments: results[0] as List<Map<String, dynamic>>,
    currentYear: results[1] as Map<String, dynamic>?,
  );
});

/// Read-only list of the active class-subject assignments for the current
/// academic year. Teachers see their own (row security limits the query);
/// assigning and reassigning happens in Class Setup.
class TeacherAssignmentsPage extends ConsumerWidget {
  const TeacherAssignmentsPage({super.key});

  String _person(Map<String, dynamic> row) =>
      [row['firstname'], row['middlename'], row['lastname']]
          .where((part) => part != null && part.toString().trim().isNotEmpty)
          .join(' ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(classesTaughtProvider);
    return UiPage(
      children: [
        const PageHead(
          kicker: 'Academics',
          title: 'Classes You Teach',
          subtitle:
              'Your class and subject assignments for the current academic year.',
        ),
        data.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading assignments…'),
          ),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(classesTaughtProvider),
          ),
          data: (value) => Panel(
            title:
                'Active assignments${value.currentYear == null ? '' : ' · ${value.currentYear!['name']}'}',
            child: DataTableCard(
              columns: const [
                UiColumn('Class', flex: 10),
                UiColumn('Subject', flex: 12),
                UiColumn('Teacher', flex: 14),
              ],
              rows: [
                for (final row in value.assignments)
                  () {
                    final staff =
                        row['staff'] as Map<String, dynamic>? ?? const {};
                    final configured =
                        row['class_subject'] as Map<String, dynamic>? ??
                        const {};
                    final classRow =
                        configured['class'] as Map<String, dynamic>? ??
                        const {};
                    final subject =
                        configured['subject'] as Map<String, dynamic>? ??
                        const {};
                    return UiTableRow([
                      UiCellText(
                        '${classRow['classroomname'] ?? 'Class'}',
                        bold: true,
                      ),
                      UiCellText('${subject['subjectname'] ?? 'Subject'}'),
                      PersonCell(_person(staff)),
                    ]);
                  }(),
              ],
              empty: const UiEmptyState(
                icon: Icons.assignment_ind_outlined,
                title: 'No active teacher assignments yet',
                message:
                    'Classes you teach appear here once an Administrator assigns you in Class Setup.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
