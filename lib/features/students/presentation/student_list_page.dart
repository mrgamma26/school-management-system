import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/student.dart';
import '../data/student_repository.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../../core/services/export_service.dart';
import 'student_form_page.dart';
import 'student_details_page.dart';

final _studentListProvider = FutureProvider<List<Student>>((ref) {
  return StudentRepository().listStudents();
});

class StudentListPage extends ConsumerStatefulWidget {
  const StudentListPage({super.key});

  @override
  ConsumerState<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends ConsumerState<StudentListPage> {
  String _query = '';
  // FIX 6: Status filter and sort
  String _statusFilter = 'ALL'; // 'ALL', 'ENROLLED', 'GRADUATED', 'WITHDRAWN'
  String _sortBy = 'name'; // 'name', 'date', 'status'
  bool _sortAscending = true;

  List<Student> _filterAndSort(List<Student> students) {
    var filtered = students;

    // Apply search filter
    if (_query.isNotEmpty) {
      filtered = students
          .where(
            (s) =>
                s.fullName.toLowerCase().contains(_query) ||
                s.studentId.toLowerCase().contains(_query),
          )
          .toList();
    }

    // Apply status filter
    if (_statusFilter != 'ALL') {
      filtered = filtered
          .where((s) => s.enrollmentStatus.toUpperCase() == _statusFilter)
          .toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.fullName.compareTo(b.fullName);
          break;
        case 'date':
          comparison = a.dateOfBirth.compareTo(b.dateOfBirth);
          break;
        case 'status':
          comparison = a.enrollmentStatus.compareTo(b.enrollmentStatus);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_studentListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export to CSV',
            onPressed: () async {
              final students = async.value;
              if (students == null || students.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No students to export')),
                  );
                }
                return;
              }

              // Apply current filters
              final filteredStudents = _filterAndSort(students);

              // Convert to map format for export
              final studentData = filteredStudents
                  .map(
                    (s) => {
                      'studentId': s.studentId,
                      'fullName': s.fullName,
                      'dateOfBirth': s.dateOfBirth.toString().split(' ')[0],
                      'gender': s.gender,
                      'enrollmentStatus': s.enrollmentStatus,
                    },
                  )
                  .toList();

              await ExportService.exportStudentListCsv(students: studentData);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Exported ${filteredStudents.length} students to CSV',
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_studentListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const StudentFormPage()),
          );
          if (mounted) ref.invalidate(_studentListProvider);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Register Student'),
      ),
      body: Column(
        children: [
          // FIX 6: Search, filter, and sort controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or ID…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
                const SizedBox(height: 12),

                // Status filter and sort controls
                Row(
                  children: [
                    // Status filter dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.filter_list),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All')),
                          DropdownMenuItem(
                            value: 'ENROLLED',
                            child: Text('Enrolled'),
                          ),
                          DropdownMenuItem(
                            value: 'GRADUATED',
                            child: Text('Graduated'),
                          ),
                          DropdownMenuItem(
                            value: 'WITHDRAWN',
                            child: Text('Withdrawn'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _statusFilter = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(
                          labelText: 'Sort by',
                          prefixIcon: Icon(Icons.sort),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'name', child: Text('Name')),
                          DropdownMenuItem(
                            value: 'date',
                            child: Text('Birth Date'),
                          ),
                          DropdownMenuItem(
                            value: 'status',
                            child: Text('Status'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortBy = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort direction toggle
                    IconButton(
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      ),
                      tooltip: _sortAscending ? 'Ascending' : 'Descending',
                      onPressed: () {
                        setState(() => _sortAscending = !_sortAscending);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: async.when(
              loading: () => const LoadingState(message: 'Loading students…'),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(_studentListProvider),
              ),
              data: (students) {
                final filtered = _filterAndSort(students);

                if (students.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: 'No students yet',
                    subtitle:
                        'Tap the button below to register the first student.',
                    action: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudentFormPage(),
                          ),
                        );
                        if (mounted) ref.invalidate(_studentListProvider);
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Register Student'),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No results for "$_query"',
                    subtitle: 'Try a different name or admission number.',
                  );
                }

                // Count banner
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filtered.length} student${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primaryContainer,
                                child: Text(
                                  s.firstName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                s.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'ID: ${s.studentId.substring(0, 8).toUpperCase()}',
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: StatusBadge(s.enrollmentStatus),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentDetailsPage(
                                      studentId: s.studentId,
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  ref.invalidate(_studentListProvider);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
