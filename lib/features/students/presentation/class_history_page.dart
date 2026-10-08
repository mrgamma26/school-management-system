import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/can.dart';
import '../data/student_repository.dart';
import '../../../widgets/skeleton_loader.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(classHistoryProvider(studentId)),
          ),
        ],
      ),
      floatingActionButton: Can(
        permission: 'students:enrol',
        child: FloatingActionButton.extended(
          icon: const Icon(Icons.upgrade),
          label: const Text('Promote / Move Class'),
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
      body: historyAsync.when(
        loading: () => const SkeletonListLoader(itemCount: 4, itemHeight: 88),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (history) => history.isEmpty
            ? const Center(child: Text('No class history recorded.'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: history.length,
                itemBuilder: (_, i) {
                  final row = history[i];
                  final cls = row['class'] as Map<String, dynamic>?;
                  final year = row['academicyear'] as Map<String, dynamic>?;
                  final isActive = row['enddate'] == null;

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isActive ? Icons.circle : Icons.circle_outlined,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                      title: Text(cls?['classroomname'] as String? ?? '—'),
                      subtitle: Text(
                        '${year?['academicyear'] ?? ''} '
                        '${year?['term'] ?? ''}\n'
                        'From: ${row['enrollmentdate']}'
                        '${row['enddate'] != null ? '  To: ${row['enddate']}' : '  (current)'}',
                      ),
                      isThreeLine: true,
                      trailing: isActive
                          ? const Chip(label: Text('Active'))
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
