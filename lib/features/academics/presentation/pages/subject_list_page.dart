import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/subject.dart';
import 'subject_form_page.dart';

final _subjectsProvider = FutureProvider<List<Subject>>((ref) {
  return AcademicRepository().listSubjects();
});

class SubjectListPage extends ConsumerWidget {
  const SubjectListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_subjectsProvider);
    final role = ref.watch(authProvider).user?.roleName ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects'),
        actions: [
          HomeButton(roleName: role),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(_subjectsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubjectFormPage()),
          );
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
            return EmptyState(
              icon: Icons.book_outlined,
              title: 'No subjects yet',
              subtitle: 'Add subjects for teachers to use in assessments.',
              action: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubjectFormPage()),
                  );
                  ref.invalidate(_subjectsProvider);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Subject'),
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
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectFormPage(existing: s),
                      ),
                    );
                    ref.invalidate(_subjectsProvider);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
