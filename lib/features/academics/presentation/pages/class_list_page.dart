import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/class_model.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

final _classesProvider = FutureProvider.autoDispose<List<ClassModel>>((ref) {
  return AcademicRepository().listClasses();
});

class ClassListPage extends ConsumerWidget {
  const ClassListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_classesProvider);
    final cs = Theme.of(context).colorScheme;
    final canEdit = ref
        .watch(permissionsProvider)
        .maybeWhen(
          data: (permissions) => permissions.contains('academics:write'),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(_classesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/academics/classes/new');
          ref.invalidate(_classesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading classes…'),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_classesProvider),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EmptyState(
                    icon: Icons.class_outlined,
                    title: 'No classes yet',
                    subtitle: 'Add classes to organise students by form.',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await context.push('/academics/classes/new');
                      ref.invalidate(_classesProvider);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Class'),
                  ),
                ],
              ),
            );
          }

          // Group by form level
          final grouped = <String, List<ClassModel>>{};
          for (final c in classes) {
            grouped.putIfAbsent(c.form ?? 'OTHER', () => []).add(c);
          }

          // Sort form keys
          final sortedKeys = grouped.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            children: sortedKeys.map((form) {
              final formClasses = grouped[form]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.class_,
                      color: AppColors.secondary,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    _label(form),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${formClasses.length} class${formClasses.length == 1 ? '' : 'es'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  initiallyExpanded: true,
                  children: formClasses.map((cls) {
                    return ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
                      leading: const Icon(
                        Icons.door_front_door_outlined,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                      title: Text(cls.className),
                      trailing: canEdit
                          ? const Icon(Icons.edit_outlined, size: 18)
                          : null,
                      onTap: canEdit
                          ? () async {
                              await context.push(
                                '/academics/classes/${cls.classId}/edit',
                                extra: cls,
                              );
                              ref.invalidate(_classesProvider);
                            }
                          : null,
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _label(String form) {
    switch (form) {
      case 'FORM_1':
        return 'Form 1';
      case 'FORM_2':
        return 'Form 2';
      case 'FORM_3':
        return 'Form 3';
      case 'FORM_4':
        return 'Form 4';
      default:
        return 'Other';
    }
  }
}
