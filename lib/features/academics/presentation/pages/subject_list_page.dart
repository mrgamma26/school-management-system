import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/subject.dart';

final _subjectsProvider = FutureProvider.autoDispose<List<Subject>>((ref) {
  return AcademicRepository().listSubjects();
});

/// Screen 23 - Reusable school-wide subject catalogue.
class SubjectListPage extends ConsumerStatefulWidget {
  const SubjectListPage({super.key});

  @override
  ConsumerState<SubjectListPage> createState() => _SubjectListPageState();
}

class _SubjectListPageState extends ConsumerState<SubjectListPage> {
  String _query = '';

  Future<void> _add() async {
    final saved = await context.push<bool>('/academics/subjects/new');
    if (saved == true) ref.invalidate(_subjectsProvider);
  }

  Future<void> _edit(Subject s) async {
    final saved = await context.push<bool>(
      '/academics/subjects/${s.subjectId}/edit',
      extra: s,
    );
    if (saved == true) ref.invalidate(_subjectsProvider);
  }

  Future<void> _delete(Subject s) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text(
          'Delete "${s.subjectName}"? A subject assigned to a class cannot be deleted until its class assignment is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AcademicRepository().deleteSubject(s.subjectId);
      ref.invalidate(_subjectsProvider);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete subject: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_subjectsProvider);
    final canEdit = ref
        .watch(permissionsProvider)
        .maybeWhen(
          data: (permissions) => permissions.contains('academics:write'),
          orElse: () => false,
        );

    return UiPage(
      children: [
        PageHead(
          kicker: 'Academics',
          title: 'Subjects',
          subtitle: 'Reusable school-wide subject catalogue.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_subjectsProvider),
            ),
            UiButton('Add Subject', icon: Icons.add_rounded, onPressed: _add),
          ],
        ),
        UiToolbar(
          searchHint: 'Search subjects',
          onSearch: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading subjects…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_subjectsProvider),
          ),
          data: (subjects) {
            if (subjects.isEmpty) {
              return UiCard(
                child: UiEmptyState(
                  icon: Icons.book_outlined,
                  title: 'No subjects yet',
                  message: 'Add subjects for teachers to use in assessments.',
                  action: UiButton(
                    'Create Subject',
                    icon: Icons.add_rounded,
                    onPressed: _add,
                  ),
                ),
              );
            }
            final filtered = _query.isEmpty
                ? subjects
                : subjects
                      .where(
                        (s) => s.subjectName.toLowerCase().contains(_query),
                      )
                      .toList();
            if (filtered.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.search_off,
                  title: 'No matching subjects',
                  message: 'Try a different search term.',
                ),
              );
            }
            return DataTableCard(
              columns: [
                const UiColumn('Subject', flex: 12),
                const UiColumn('Description', flex: 16, hideOnPhone: true),
                UiColumn(canEdit ? 'Actions' : '', width: 92),
              ],
              rows: [
                for (final s in filtered)
                  UiTableRow([
                    PersonCell(s.subjectName),
                    UiCellText(
                      s.description != null && s.description!.isNotEmpty
                          ? s.description!
                          : '—',
                    ),
                    canEdit
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 19),
                                tooltip: 'Edit subject',
                                onPressed: () => _edit(s),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 19,
                                ),
                                tooltip: 'Delete subject',
                                color: Colors.red,
                                onPressed: () => _delete(s),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ], onTap: canEdit ? () => _edit(s) : null),
              ],
            );
          },
        ),
      ],
    );
  }
}
