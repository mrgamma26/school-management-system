import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/subject.dart';

final _subjectsProvider = FutureProvider.autoDispose<List<Subject>>((ref) {
  return AcademicRepository().listSubjects();
});

class SubjectListPage extends ConsumerWidget {
  const SubjectListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_subjectsProvider);
    final cs = Theme.of(context).colorScheme;
    final canEdit = ref
        .watch(permissionsProvider)
        .maybeWhen(
          data: (permissions) => permissions.contains('academics:write'),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(_subjectsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/academics/subjects/new');
          ref.invalidate(_subjectsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading subjects...'),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_subjectsProvider),
        ),
        data: (subjects) {
          if (subjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EmptyState(
                    icon: Icons.book_outlined,
                    title: 'No subjects yet',
                    subtitle:
                        'Add subjects for teachers to use in assessments.',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await context.push('/academics/subjects/new');
                      ref.invalidate(_subjectsProvider);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Subject'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: subjects.length,
            itemBuilder: (_, i) {
              final s = subjects[i];
              return Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.book,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    s.subjectName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: s.description != null && s.description!.isNotEmpty
                      ? Text(
                          s.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        )
                      : null,
                  trailing: canEdit
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit subject',
                              onPressed: () async {
                                await context.push(
                                  '/academics/subjects/${s.subjectId}/edit',
                                  extra: s,
                                );
                                ref.invalidate(_subjectsProvider);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete subject',
                              color: Colors.red,
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete Subject'),
                                    content: Text(
                                      'Delete "${s.subjectName}"? A subject assigned to a class cannot be deleted until its class assignment is removed.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                try {
                                  await AcademicRepository().deleteSubject(
                                    s.subjectId,
                                  );
                                  ref.invalidate(_subjectsProvider);
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not delete subject: $error',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        )
                      : null,
                  onTap: canEdit
                      ? () async {
                          await context.push(
                            '/academics/subjects/${s.subjectId}/edit',
                            extra: s,
                          );
                          ref.invalidate(_subjectsProvider);
                        }
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
