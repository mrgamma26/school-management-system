import 'package:school_management_app/features/academics/domain/models/academic_year.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/student.dart';
import '../data/student_repository.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../../core/services/export_service.dart';
import '../../academics/data/academic_repository.dart';
import '../../../widgets/can.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../widgets/skeleton_loader.dart';

final _studentListProvider = FutureProvider<List<Student>>((ref) {
  return StudentRepository().listStudents();
});

final _currentAcademicYearsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
      return AcademicRepository().currentAcademicYears();
    });

final _teacherClassesProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String userId, String yearId})
    >((ref, args) {
      return AcademicRepository().teacherClasses(
        userId: args.userId,
        academicYearId: args.yearId,
      );
    });

final _teacherStudentsProvider =
    FutureProvider.family<List<Student>, ({String classId, String yearId})>((
      ref,
      args,
    ) {
      return StudentRepository().listStudentsForClass(
        classId: args.classId,
        academicYearId: args.yearId,
      );
    });

class StudentListPage extends ConsumerStatefulWidget {
  const StudentListPage({super.key});

  @override
  ConsumerState<StudentListPage> createState() => _StudentListPageState();
}

class _TeacherStudentFilters extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> years;
  final AsyncValue<List<Map<String, dynamic>>>? classes;
  final String? selectedYearId;
  final String? selectedClassId;
  final ValueChanged<String?> onYearChanged;
  final ValueChanged<String?> onClassChanged;

  const _TeacherStudentFilters({
    required this.years,
    required this.classes,
    required this.selectedYearId,
    required this.selectedClassId,
    required this.onYearChanged,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: years.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) =>
                  Text('Unable to load academic years: $error'),
              data: (items) => DropdownButtonFormField<String>(
                initialValue: selectedYearId,
                decoration: const InputDecoration(
                  labelText: 'Academic year',
                  border: OutlineInputBorder(),
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item['academicyearid'] as String,
                        child: Text(formatAcademicYear(item['academicyear'])),
                      ),
                    )
                    .toList(),
                onChanged: onYearChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: classes == null
                ? const SizedBox.shrink()
                : classes!.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Unable to load classes: $error'),
                    data: (items) => DropdownButtonFormField<String>(
                      initialValue: selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      items: items
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['classid'] as String,
                              child: Text(
                                (item['classname'] ??
                                        item['classroomname'] ??
                                        'Class')
                                    .toString(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: onClassChanged,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudentListPageState extends ConsumerState<StudentListPage> {
  String _query = '';
  // FIX 6: Status filter and sort
  String _statusFilter = 'ALL'; // 'ALL', 'ENROLLED', 'GRADUATED', 'WITHDRAWN'
  String _sortBy = 'name'; // 'name', 'date', 'status'
  bool _sortAscending = true;
  String? _teacherYearId;
  String? _teacherClassId;
  String? _adminAcademicYearId; // Academic year filter for admins

  void _refreshStudents() {
    ref.invalidate(_studentListProvider);
    if (_teacherYearId != null && _teacherClassId != null) {
      ref.invalidate(
        _teacherStudentsProvider((
          yearId: _teacherYearId!,
          classId: _teacherClassId!,
        )),
      );
    }
  }

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
    final user = ref.watch(authProvider).user;
    final permHelper = ref.watch(permissionHelperProvider);
    final isTeacher = permHelper.maybeWhen(
      data: (perm) => perm?.roleName.toUpperCase() == 'TEACHER',
      orElse: () => false,
    );
    final currentYears = isTeacher
        ? ref.watch(_currentAcademicYearsProvider)
        : null;
    final yearItems = currentYears?.asData?.value;
    final selectedYearId =
        _teacherYearId ??
        (yearItems?.isNotEmpty == true
            ? yearItems!.first['academicyearid'] as String
            : null);
    final classes = isTeacher && selectedYearId != null
        ? ref.watch(
            _teacherClassesProvider((
              userId: user!.userId,
              yearId: selectedYearId,
            )),
          )
        : null;
    final classItems = classes?.asData?.value;
    final selectedClassId =
        _teacherClassId ??
        (classItems?.isNotEmpty == true
            ? classItems!.first['classid'] as String
            : null);
    final async = isTeacher
        ? (selectedYearId != null && selectedClassId != null
              ? ref.watch(
                  _teacherStudentsProvider((
                    yearId: selectedYearId,
                    classId: selectedClassId,
                  )),
                )
              : const AsyncData<List<Student>>([]))
        : ref.watch(_studentListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          Can(
            permission: 'students:enrol',
            child: IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Add Student',
              onPressed: () async {
                await context.push<bool>('/students/new');
                if (mounted) _refreshStudents();
              },
            ),
          ),
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

              // Capture messenger before async gap to satisfy
              // use_build_context_synchronously lint.
              final messenger = ScaffoldMessenger.of(context);
              await ExportService.exportStudentListCsv(students: studentData);

              if (mounted) {
                messenger.showSnackBar(
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
      floatingActionButton: Can(
        permission: 'students:enrol',
        child: FloatingActionButton.extended(
          onPressed: () async {
            await context.push<bool>('/students/new');
            if (mounted) _refreshStudents();
          },
          icon: const Icon(Icons.person_add),
          label: const Text('Register Student'),
        ),
      ),
      body: Column(
        children: [
          if (isTeacher)
            _TeacherStudentFilters(
              years: currentYears!,
              classes: classes,
              selectedYearId: selectedYearId,
              selectedClassId: selectedClassId,
              onYearChanged: (yearId) => setState(() {
                _teacherYearId = yearId;
                _teacherClassId = null;
              }),
              onClassChanged: (classId) =>
                  setState(() => _teacherClassId = classId),
            ),
          // FIX 6: Search, filter, and sort controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Column(
              children: [
                // Academic year filter for admins
                if (!isTeacher)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child:
                        currentYears?.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) =>
                              Text('Unable to load academic years: $error'),
                          data: (items) => DropdownButtonFormField<String>(
                            initialValue: _adminAcademicYearId,
                            decoration: const InputDecoration(
                              labelText: 'Academic Year',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Years'),
                              ),
                              ...items.map(
                                (item) => DropdownMenuItem<String>(
                                  value: item['academicyearid'] as String,
                                  child: Text(
                                    formatAcademicYear(item['academicyear']),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _adminAcademicYearId = value);
                            },
                          ),
                        ) ??
                        const SizedBox.shrink(),
                  ),
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
                        initialValue: _statusFilter,
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
                        initialValue: _sortBy,
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
              loading: () =>
                  const SkeletonListLoader(itemCount: 6, itemHeight: 88),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(_studentListProvider),
              ),
              data: (students) {
                final filtered = _filterAndSort(students);

                if (students.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No students yet',
                    subtitle:
                        'Use the Register Student button to add the first student.',
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
                                await context.push('/students/${s.studentId}');
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
