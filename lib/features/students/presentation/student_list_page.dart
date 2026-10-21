import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_management_app/features/academics/domain/models/academic_year.dart';

import '../../../core/auth/permission_helper.dart';
import '../../../core/services/export_service.dart';
import '../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../widgets/can.dart';
import '../../../widgets/ui_kit.dart';
import '../../academics/data/academic_repository.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../data/student_repository.dart';
import '../domain/student.dart';

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

/// Screen 8 - Students register.
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
      padding: const EdgeInsets.only(bottom: 12),
      child: UiCard(
        padding: const EdgeInsets.all(12),
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
                    isDense: true,
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
            const SizedBox(width: 10),
            Expanded(
              child: classes == null
                  ? const SizedBox.shrink()
                  : classes!.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) =>
                          Text('Unable to load classes: $error'),
                      data: (items) => DropdownButtonFormField<String>(
                        initialValue: selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          isDense: true,
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
      ),
    );
  }
}

class _StudentListPageState extends ConsumerState<StudentListPage> {
  static const _pageSize = 25;

  String _query = '';
  String _statusFilter = 'ALL'; // 'ALL', 'ENROLLED', 'GRADUATED', 'WITHDRAWN'
  String _sortBy = 'name'; // 'name', 'date', 'status'
  bool _sortAscending = true;
  String? _teacherYearId;
  String? _teacherClassId;
  int _page = 0;

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

    if (_query.isNotEmpty) {
      filtered = students
          .where(
            (s) =>
                s.fullName.toLowerCase().contains(_query) ||
                s.studentId.toLowerCase().contains(_query),
          )
          .toList();
    }

    if (_statusFilter != 'ALL') {
      filtered = filtered
          .where((s) => s.enrollmentStatus.toUpperCase() == _statusFilter)
          .toList();
    }

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

  Future<void> _addStudent() async {
    await context.push<bool>('/students/new');
    if (mounted) _refreshStudents();
  }

  Future<void> _export(AsyncValue<List<Student>> async) async {
    final students = async.value;
    final messenger = ScaffoldMessenger.of(context);
    if (students == null || students.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No students to export')),
      );
      return;
    }

    final filteredStudents = _filterAndSort(students);
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported ${filteredStudents.length} students to CSV'),
        ),
      );
    }
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

    return UiPage(
      children: [
        PageHead(
          kicker: 'People',
          title: 'Students',
          subtitle: 'Searchable student register organized by status.',
          actions: [
            UiButton.secondary(
              'Export',
              icon: Icons.file_download_outlined,
              onPressed: () => _export(async),
            ),
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: _refreshStudents,
            ),
            Can(
              permission: 'students:enrol',
              child: UiButton(
                'Register Student',
                icon: Icons.person_add_alt,
                onPressed: _addStudent,
              ),
            ),
          ],
        ),
        if (isTeacher)
          _TeacherStudentFilters(
            years: currentYears!,
            classes: classes,
            selectedYearId: selectedYearId,
            selectedClassId: selectedClassId,
            onYearChanged: (yearId) => setState(() {
              _teacherYearId = yearId;
              _teacherClassId = null;
              _page = 0;
            }),
            onClassChanged: (classId) => setState(() {
              _teacherClassId = classId;
              _page = 0;
            }),
          ),
        UiToolbar(
          searchHint: 'Search by name or ID',
          onSearch: (v) => setState(() {
            _query = v.trim().toLowerCase();
            _page = 0;
          }),
          trailing: [
            for (final (value, label) in const [
              ('ALL', 'All'),
              ('ENROLLED', 'Enrolled'),
              ('GRADUATED', 'Graduated'),
              ('WITHDRAWN', 'Withdrawn'),
            ])
              FilterChipBox(
                label,
                selected: _statusFilter == value,
                onTap: () => setState(() {
                  _statusFilter = value;
                  _page = 0;
                }),
              ),
            _SortMenu(
              sortBy: _sortBy,
              ascending: _sortAscending,
              onSortBy: (value) => setState(() {
                _sortBy = value;
                _page = 0;
              }),
              onToggleDirection: () =>
                  setState(() => _sortAscending = !_sortAscending),
            ),
          ],
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading students…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_studentListProvider),
          ),
          data: (students) {
            if (students.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.people_outline,
                  title: 'No students yet',
                  message:
                      'Use the Register Student button to add the first student.',
                ),
              );
            }
            final filtered = _filterAndSort(students);
            if (filtered.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.search_off,
                  title: 'No matching students',
                  message: 'Try a different name, ID or status filter.',
                ),
              );
            }
            final pageCount = (filtered.length / _pageSize).ceil();
            final page = _page.clamp(0, pageCount - 1);
            final visible = PagerBar.slice(filtered, page, _pageSize);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTableCard(
                  columns: const [
                    UiColumn('Student', flex: 18),
                    UiColumn('Reference', flex: 10, hideOnPhone: true),
                    UiColumn('Gender', flex: 8, hideOnPhone: true),
                    UiColumn('Date of birth', flex: 11, hideOnPhone: true),
                    UiColumn('Status', flex: 10),
                    UiColumn('', width: 24),
                  ],
                  rows: [
                    for (final s in visible)
                      UiTableRow(
                        [
                          PersonCell(s.fullName),
                          UiCellText(s.studentId.substring(0, 8).toUpperCase()),
                          UiCellText(s.gender),
                          UiCellText(formatUiDate(s.dateOfBirth)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: StatusPill.auto(s.enrollmentStatus),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF64758B),
                          ),
                        ],
                        onTap: () async {
                          await context.push('/students/${s.studentId}');
                          if (mounted) ref.invalidate(_studentListProvider);
                        },
                      ),
                  ],
                ),
                PagerBar(
                  total: filtered.length,
                  page: page,
                  pageSize: _pageSize,
                  onPage: (p) => setState(() => _page = p),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Sort chip: opens a menu to pick the field and flip the direction.
class _SortMenu extends StatelessWidget {
  final String sortBy;
  final bool ascending;
  final ValueChanged<String> onSortBy;
  final VoidCallback onToggleDirection;

  const _SortMenu({
    required this.sortBy,
    required this.ascending,
    required this.onSortBy,
    required this.onToggleDirection,
  });

  static const _labels = {
    'name': 'Name',
    'date': 'Birth date',
    'status': 'Status',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Sort students',
      onSelected: (value) =>
          value == '_direction' ? onToggleDirection() : onSortBy(value),
      itemBuilder: (_) => [
        for (final entry in _labels.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: entry.key == sortBy,
            child: Text(entry.value),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: '_direction',
          child: Text(
            ascending ? 'Switch to descending' : 'Switch to ascending',
          ),
        ),
      ],
      child: IgnorePointer(
        child: FilterChipBox(
          'Sort: ${_labels[sortBy]} ${ascending ? '↑' : '↓'}',
        ),
      ),
    );
  }
}
