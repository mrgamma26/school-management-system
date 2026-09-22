import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/academic_year.dart';
import 'academic_year_form_page.dart';

final _academicYearsProvider = FutureProvider<List<AcademicYear>>((ref) {
  return AcademicRepository().listAcademicYears();
});

class AcademicYearListPage extends ConsumerWidget {
  const AcademicYearListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_academicYearsProvider);
    final role = ref.watch(authProvider).user?.roleName ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Years'),
        actions: [
          HomeButton(roleName: role),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(_academicYearsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AcademicYearFormPage()),
          );
          ref.invalidate(_academicYearsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Year'),
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading academic years...'),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_academicYearsProvider),
        ),
        data: (years) {
          if (years.isEmpty) {
            return EmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'No academic years yet',
              subtitle: 'Create an academic year to start organising terms.',
              action: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AcademicYearFormPage(),
                    ),
                  );
                  ref.invalidate(_academicYearsProvider);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Year'),
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
                    '$start -> $end',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AcademicYearFormPage(existing: y),
                      ),
                    );
                    ref.invalidate(_academicYearsProvider);
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
