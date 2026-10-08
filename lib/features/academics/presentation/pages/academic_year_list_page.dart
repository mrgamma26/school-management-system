import '../../../../core/auth/school_role_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../widgets/skeleton_loader.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/academic_year.dart';

final _academicYearsProvider = FutureProvider<List<AcademicYear>>((ref) {
  return AcademicRepository().listAcademicYears();
});

class AcademicYearListPage extends ConsumerWidget {
  const AcademicYearListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_academicYearsProvider);
    final user = ref.watch(authProvider).user;

    // Allow edit if user is ADMIN or above (ADMIN, SUPER_ADMIN)
    final canEdit = canManageSchoolCalendar(user?.roleName ?? '');

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Years'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(_academicYearsProvider),
          ),
        ],
      ),
      floatingActionButton: !canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/academics/years/new');
                ref.invalidate(_academicYearsProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Year'),
            ),
      body: async.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: 5,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SkeletonCard(height: 80, padding: const EdgeInsets.all(0)),
          ),
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_academicYearsProvider),
        ),
        data: (years) {
          if (years.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EmptyState(
                    icon: Icons.calendar_today_outlined,
                    title: 'No academic years yet',
                    subtitle:
                        'Create an academic year to organise your school.',
                  ),
                  const SizedBox(height: 24),
                  if (canEdit)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await context.push('/academics/years/new');
                        ref.invalidate(_academicYearsProvider);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Academic Year'),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: years.length,
            itemBuilder: (_, i) {
              final y = years[i];
              final start = y.startDate.toIso8601String().substring(0, 10);
              final end = y.endDate.toIso8601String().substring(0, 10);

              return Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: cs.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    y.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${formatFormLevel(y.form)} • ${y.term.replaceAll('_', ' ')} • $start → $end',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: canEdit
                      ? () async {
                          await context.push(
                            '/academics/years/${y.id}/edit',
                            extra: y,
                          );
                          ref.invalidate(_academicYearsProvider);
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
