import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/can.dart';
import '../../../../widgets/ui_kit.dart';
import '../data/student_repository.dart';

final classHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) {
      return StudentRepository().getClassHistory(studentId);
    });

/// Shows the class-placement history for one student
/// and allows assigning a new class.
class ClassHistoryPage extends ConsumerWidget {
  final String studentId;
  const ClassHistoryPage({required this.studentId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(classHistoryProvider(studentId));
    return UiPage(
      children: [
        PageHead(
          kicker: 'Students',
          title: 'Class History',
          subtitle: 'Every class this learner has been placed in.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(classHistoryProvider(studentId)),
            ),
            Can(
              permission: 'students:enrol',
              child: UiButton(
                'Promote / Move Class',
                icon: Icons.upgrade_rounded,
                onPressed: () async {
                  final promoted = await context.push<bool>(
                    '/students/$studentId/class-history/promote',
                  );
                  if (promoted == true && context.mounted) {
                    ref.invalidate(classHistoryProvider(studentId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Student class updated.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading class history…'),
          ),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(classHistoryProvider(studentId)),
          ),
          data: (history) => history.isEmpty
              ? const UiCard(
                  child: UiEmptyState(
                    icon: Icons.history_rounded,
                    title: 'No class history recorded',
                  ),
                )
              : DataTableCard(
                  columns: const [
                    UiColumn('Class', flex: 14),
                    UiColumn('Academic year', flex: 12, hideOnPhone: true),
                    UiColumn('From', flex: 10),
                    UiColumn('To', flex: 10, hideOnPhone: true),
                    UiColumn('Status', width: 90),
                  ],
                  rows: [
                    for (final row in history)
                      _historyRow(row),
                  ],
                ),
        ),
      ],
    );
  }

  UiTableRow _historyRow(Map<String, dynamic> row) {
    final cls = row['class'] as Map<String, dynamic>?;
    final year = row['academicyear'] as Map<String, dynamic>?;
    final isActive = row['enddate'] == null;
    final yearLabel = '${year?['academicyear'] ?? ''} ${year?['term'] ?? ''}'
        .trim();
    return UiTableRow([
      PersonCell(cls?['classroomname'] as String? ?? '—'),
      UiCellText(yearLabel.isEmpty ? '—' : yearLabel),
      UiCellText(_date(row['enrollmentdate'])),
      UiCellText(isActive ? 'Current' : _date(row['enddate'])),
      Align(
        alignment: Alignment.centerLeft,
        child: isActive
            ? const StatusPill('Active', tone: StatusTone.success)
            : const StatusPill('Ended', tone: StatusTone.neutral),
      ),
    ]);
  }

  static String _date(Object? value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null ? value.toString() : formatUiDate(parsed);
  }
}
