import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/errors/app_exception.dart' show friendlyError;
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/academic_repository.dart';
import '../../data/academic_setup_repository.dart';
import '../../domain/class_setup_matrix.dart';

class _SetupData {
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> configured;
  final List<Map<String, dynamic>> teachers;
  final List<Map<String, dynamic>> staffSubjects;
  final List<Map<String, dynamic>> assignments;
  final String? yearName;

  const _SetupData({
    required this.classes,
    required this.subjects,
    required this.configured,
    required this.teachers,
    required this.staffSubjects,
    required this.assignments,
    required this.yearName,
  });

  ClassSetupMatrix get matrix => ClassSetupMatrix.build(
    classes: classes,
    subjects: subjects,
    configured: configured,
    assignments: assignments,
  );

  Set<String> offeredSubjectIds(String classId) => {
    for (final row in configured)
      if (row['class_id'] == classId) row['subject_id'] as String,
  };
}

/// Class Setup: the one place to create classes, link subjects to them and
/// assign one teacher per subject.
///
/// Left: a class dropdown and the list of classes with their progress.
/// Right: the subjects of the selected class, each with a dropdown of the
/// teachers marked as teaching that subject, and a Reassign button once a
/// teacher is in place. The current academic year is applied automatically.
///
/// Only an Administrator or Super User can change anything; other roles that
/// reach the page (the Head Teacher) see it read-only.
class ClassSetupPage extends ConsumerStatefulWidget {
  /// Open this class instead of the first one.
  final String? initialClassId;

  final AcademicRepository? academicRepository;
  final AcademicSetupRepository? setupRepository;

  const ClassSetupPage({
    super.key,
    this.initialClassId,
    this.academicRepository,
    this.setupRepository,
  });

  @override
  ConsumerState<ClassSetupPage> createState() => _ClassSetupPageState();
}

class _ClassSetupPageState extends ConsumerState<ClassSetupPage> {
  late final AcademicRepository _academic =
      widget.academicRepository ?? AcademicRepository();
  late final AcademicSetupRepository _setup =
      widget.setupRepository ?? AcademicSetupRepository();

  _SetupData? _data;
  Object? _loadError;
  bool _loading = true;
  bool _saving = false;

  String? _classId;
  String? _banner;
  String? _error;

  bool get _canManage =>
      canManageAcademicSetup(ref.read(activeWorkspaceRoleProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false, String? selectClassId}) async {
    if (!silent) setState(() => _loading = true);
    final manage = _canManage;
    try {
      final results = await Future.wait<Object?>([
        _setup.classes(),
        _setup.subjects(),
        _setup.configuredSubjects(),
        // Only managers pick teachers, so other roles skip these two reads.
        manage ? _setup.teachers() : Future.value(const []),
        manage ? _setup.staffSubjects() : Future.value(const []),
        _setup.currentYearAssignments(),
        _setup.currentAcademicYear(),
      ]);
      if (!mounted) return;
      List<Map<String, dynamic>> rows(int i) =>
          List<Map<String, dynamic>>.from(results[i] as List);
      final data = _SetupData(
        classes: rows(0),
        subjects: rows(1),
        configured: rows(2),
        teachers: rows(3),
        staffSubjects: rows(4),
        assignments: rows(5),
        yearName: (results[6] as Map<String, dynamic>?)?['name'] as String?,
      );
      setState(() {
        _data = data;
        _loadError = null;
        _loading = false;
        final wanted = selectClassId ?? _classId ?? widget.initialClassId;
        final ids = {for (final c in data.classes) c['classid'] as String};
        _classId = ids.contains(wanted)
            ? wanted
            : (data.classes.isEmpty
                  ? null
                  : data.classes.first['classid'] as String);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? get _class {
    final data = _data;
    if (data == null || _classId == null) return null;
    for (final row in data.classes) {
      if (row['classid'] == _classId) return row;
    }
    return null;
  }

  String get _className => (_class?['classroomname'] ?? '').toString();

  String _teacherName(String? staffId) {
    final data = _data;
    if (data == null || staffId == null) return '';
    for (final row in data.teachers) {
      if (row['staffid'] == staffId) return staffDisplayName(row);
    }
    return '';
  }

  /// Runs a save, reloads from the server and shows the result banner. The
  /// action returns the banner text and, optionally, a class to open next.
  Future<void> _run(
    Future<({String banner, String? selectClassId})> Function() action,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await action();
      await _load(silent: true, selectClassId: result.selectClassId);
      if (mounted) setState(() => _banner = result.banner);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _banner = null;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _newClass() async {
    final data = _data!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => ClassNameDialog(existing: data.classes),
    );
    if (name == null || !mounted) return;
    await _run(() async {
      await _academic.createClass(name, formFromClassName(name)!);
      final fresh = await _setup.classes();
      final created = fresh.where(
        (c) =>
            (c['classroomname'] ?? '').toString().trim().toLowerCase() ==
            name.toLowerCase(),
      );
      return (
        banner: '$name was created. Add the subjects it studies.',
        selectClassId: created.isEmpty
            ? null
            : created.first['classid'] as String,
      );
    });
  }

  Future<void> _renameClass() async {
    final row = _class;
    if (row == null) return;
    final oldName = _className;
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          ClassNameDialog(existing: _data!.classes, renaming: row),
    );
    if (name == null || name == oldName || !mounted) return;
    await _run(() async {
      // Same form, new name: the form is stored on the class and a rename may
      // not change it (the dialog already refuses that).
      await _academic.updateClass(
        row['classid'] as String,
        name,
        row['form'] as String,
      );
      return (banner: '$oldName was renamed to $name.', selectClassId: null);
    });
  }

  Future<void> _addSubjects() async {
    final data = _data!;
    final classId = _classId!;
    final linked = data.offeredSubjectIds(classId);
    final chosen = await showDialog<Set<String>>(
      context: context,
      builder: (_) => AddSubjectsDialog(
        className: _className,
        available: [
          for (final subject in data.subjects)
            if (!linked.contains(subject['subjectid'])) subject,
        ],
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    await _run(() async {
      await _setup.configureClassSubjects(classId, {...linked, ...chosen});
      return (
        banner:
            '${chosen.length} subject${chosen.length == 1 ? '' : 's'} added to $_className. Choose a teacher for each.',
        selectClassId: null,
      );
    });
  }

  Future<void> _assign(MatrixCell cell, String subjectName, String staffId) {
    return _run(() async {
      await _setup.assignTeacher(
        staffId: staffId,
        classSubjectIds: {cell.classSubjectId},
      );
      return (
        banner:
            '${_teacherName(staffId)} now teaches $subjectName in $_className.',
        selectClassId: null,
      );
    });
  }

  Future<void> _reassign(MatrixCell cell, String subjectName) async {
    final data = _data!;
    final result = await showDialog<ReassignResult>(
      context: context,
      builder: (_) => ReassignDialog(
        subjectName: subjectName,
        className: _className,
        currentStaffId: cell.staffId!,
        currentName: cell.teacherName ?? '',
        candidates: teachersForSubject(
          subjectId: cell.subjectId,
          teachers: data.teachers,
          staffSubjects: data.staffSubjects,
          excludeStaffId: cell.staffId,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      switch (result.action) {
        case ReassignAction.change:
          await _setup.assignTeacher(
            staffId: result.staffId!,
            classSubjectIds: {cell.classSubjectId},
            replacementReason: result.reason,
          );
          return (
            banner:
                '$subjectName in $_className is now taught by ${_teacherName(result.staffId)}. ${cell.teacherName}\'s assignment is kept in history.',
            selectClassId: null,
          );
        case ReassignAction.remove:
          await _setup.removeTeacher(
            classSubjectId: cell.classSubjectId,
            reason: result.reason,
          );
          return (
            banner:
                '${cell.teacherName} was removed from $subjectName in $_className. The subject stays linked.',
            selectClassId: null,
          );
        case ReassignAction.unlink:
          await _setup.unlinkClassSubject(cell.classSubjectId);
          return (
            banner: '$subjectName was unlinked from $_className.',
            selectClassId: null,
          );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canManage = canManageAcademicSetup(
      ref.watch(activeWorkspaceRoleProvider),
    );
    return UiPage(
      children: [
        PageHead(
          kicker: 'Academics',
          title: 'Class Setup',
          subtitle: canManage
              ? 'Create classes, link their subjects and choose one teacher for each subject. The current academic year is applied automatically.'
              : 'Classes, their subjects and who teaches them in the current academic year.',
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(
              message: 'Loading classes, subjects and teachers…',
            ),
          )
        else if (_loadError != null)
          ErrorState(error: _loadError!, onRetry: () => _load())
        else
          _workspace(_data!, canManage),
      ],
    );
  }

  Widget _workspace(_SetupData data, bool canManage) {
    final matrix = data.matrix;
    final noYear = data.yearName == null;
    final left = _classPanel(data, matrix, canManage);
    final right = _subjectPanel(data, matrix, canManage, noYear);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_banner != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Banner(_banner!),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: UiNotice(_error!, icon: Icons.error_outline),
          ),
        if (noYear && canManage)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: UiNotice(
              'No current academic year is set. Set one under Academic Years before assigning teachers.',
              tone: StatusTone.warning,
              icon: Icons.info_outline,
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 820) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 14), right],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 270, child: left),
                const SizedBox(width: 16),
                Expanded(child: right),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Left: class dropdown and list ──────────────────────────────────────────

  Widget _classPanel(_SetupData data, ClassSetupMatrix matrix, bool canManage) {
    return UiCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiField(
            label: 'Class',
            child: DropdownButtonFormField<String>(
              key: ValueKey('class-pick-$_classId-${data.classes.length}'),
              initialValue: _classId,
              isExpanded: true,
              hint: const Text('No classes yet'),
              items: [
                for (final row in data.classes)
                  DropdownMenuItem(
                    value: row['classid'] as String,
                    child: Text(
                      row['classroomname'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: data.classes.isEmpty
                  ? null
                  : (id) => setState(() {
                      _classId = id;
                      _banner = null;
                      _error = null;
                    }),
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 10),
            UiButton.secondary(
              'New class',
              icon: Icons.add_rounded,
              expand: true,
              onPressed: _saving ? null : _newClass,
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'ALL CLASSES',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (data.classes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No classes yet.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          for (final row in data.classes)
            _ClassTile(
              name: row['classroomname'] as String,
              progress:
                  '${matrix.assignedInClass(row['classid'] as String)}/${matrix.offeredInClass(row['classid'] as String)}',
              selected: row['classid'] == _classId,
              onTap: () => setState(() {
                _classId = row['classid'] as String;
                _banner = null;
                _error = null;
              }),
            ),
          const SizedBox(height: 12),
          StatusPill(
            data.yearName == null
                ? 'No current academic year'
                : 'Academic year ${data.yearName}',
            tone: data.yearName == null ? StatusTone.warning : StatusTone.info,
          ),
        ],
      ),
    );
  }

  // ── Right: subjects of the selected class ──────────────────────────────────

  Widget _subjectPanel(
    _SetupData data,
    ClassSetupMatrix matrix,
    bool canManage,
    bool noYear,
  ) {
    final classId = _classId;
    if (classId == null) {
      return UiCard(
        child: UiEmptyState(
          icon: Icons.class_outlined,
          title: 'No classes yet',
          message: canManage
              ? 'Create your first class, for example Form 1A, then add its subjects.'
              : 'Classes appear here once an Administrator creates them.',
          action: canManage
              ? UiButton(
                  'New class',
                  icon: Icons.add_rounded,
                  onPressed: _newClass,
                )
              : null,
        ),
      );
    }
    final subjects = matrix.subjectsOfClass(classId);
    final linked = data.offeredSubjectIds(classId);
    return UiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_className subjects',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (canManage) ...[
                UiButton.secondary(
                  'Rename',
                  icon: Icons.edit_outlined,
                  onPressed: _saving ? null : _renameClass,
                ),
                if (linked.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  UiButton.secondary(
                    'Add subjects',
                    icon: Icons.add_rounded,
                    onPressed: _saving ? null : _addSubjects,
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (subjects.isEmpty)
            UiEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No subjects linked to $_className yet',
              message: data.subjects.isEmpty
                  ? 'Create subjects first under Academics, then link them here.'
                  : canManage
                  ? 'Add the subjects this class studies, then choose a teacher for each.'
                  : null,
              action: !canManage
                  ? null
                  : data.subjects.isEmpty
                  ? UiButton.secondary(
                      'Open subjects',
                      onPressed: () => context.push('/academics/subjects'),
                    )
                  : UiButton(
                      'Add subjects',
                      icon: Icons.add_rounded,
                      onPressed: _saving ? null : _addSubjects,
                    ),
            )
          else ...[
            const _TableHeader(),
            for (final subject in subjects)
              _subjectRow(
                data,
                matrix,
                classId,
                subject,
                canManage: canManage,
                enabled: !_saving && !noYear,
              ),
            if (canManage)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Only teachers marked as teaching a subject appear in its list. One teacher per subject.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _subjectRow(
    _SetupData data,
    ClassSetupMatrix matrix,
    String classId,
    Map<String, dynamic> subject, {
    required bool canManage,
    required bool enabled,
  }) {
    final subjectId = subject['subjectid'] as String;
    final subjectName = subject['subjectname'] as String;
    final cell = matrix.cell(classId, subjectId)!;

    Widget teacher;
    Widget? action;
    if (cell.isAssigned) {
      final name = cell.teacherName ?? '';
      teacher = Row(
        children: [
          MiniAvatar(name, size: 26),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
      if (canManage) {
        action = UiButton.secondary(
          'Reassign',
          icon: Icons.swap_horiz_rounded,
          onPressed: enabled ? () => _reassign(cell, subjectName) : null,
        );
      }
    } else if (!canManage) {
      teacher = const Text(
        'Not assigned',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      );
    } else {
      final candidates = teachersForSubject(
        subjectId: subjectId,
        teachers: data.teachers,
        staffSubjects: data.staffSubjects,
      );
      if (candidates.isEmpty) {
        teacher = const Text(
          'No teacher marked for this subject',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        );
        action = TextButton(
          onPressed: () => context.push('/users/staff'),
          child: const Text('Open staff'),
        );
      } else {
        teacher = DropdownButtonFormField<String>(
          key: ValueKey(
            'teacher-${cell.classSubjectId}-${matrix.assignedCount}',
          ),
          initialValue: null,
          isExpanded: true,
          isDense: true,
          hint: const Text('Select teacher'),
          items: [
            for (final row in candidates)
              DropdownMenuItem(
                value: row['staffid'] as String,
                child: Text(
                  _teacherLabel(row, matrix.loadOf(row['staffid'] as String)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: enabled
              ? (id) {
                  if (id != null) _assign(cell, subjectName, id);
                }
              : null,
        );
      }
    }

    final status = StatusPill(
      cell.isAssigned ? 'Assigned' : 'Needs teacher',
      tone: cell.isAssigned ? StatusTone.success : StatusTone.warning,
    );
    final name = Text(
      subjectName,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: name),
                    status,
                  ],
                ),
                const SizedBox(height: 8),
                teacher,
                if (action != null) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: action),
                ],
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 10, child: name),
              Expanded(flex: 14, child: teacher),
              SizedBox(width: 110, child: Center(child: status)),
              SizedBox(
                width: 130,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: action ?? const SizedBox.shrink(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _teacherLabel(Map<String, dynamic> row, int load) =>
      '${staffDisplayName(row)} ($load subject${load == 1 ? '' : 's'})';
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.7,
      color: AppColors.textSecondary,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(flex: 10, child: Text('SUBJECT', style: style)),
              Expanded(flex: 14, child: Text('TEACHER', style: style)),
              SizedBox(
                width: 110,
                child: Center(child: Text('STATUS', style: style)),
              ),
              SizedBox(width: 130),
            ],
          ),
        );
      },
    );
  }
}

class _ClassTile extends StatelessWidget {
  final String name;
  final String progress;
  final bool selected;
  final VoidCallback onTap;

  const _ClassTile({
    required this.name,
    required this.progress,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $progress assigned',
      child: Material(
        color: selected ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  progress,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StatusTone.success.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialogs ──────────────────────────────────────────────────────────────────

/// Asks for a class name only, to create a class or rename one. The form level
/// is read from the name ("Form 2B" is a Form 2 class), so there is no level
/// to choose. A rename must stay in the class's current form.
class ClassNameDialog extends StatefulWidget {
  final List<Map<String, dynamic>> existing;

  /// The class being renamed (`classid`, `classroomname`, `form`), or null to
  /// create a new one.
  final Map<String, dynamic>? renaming;

  const ClassNameDialog({super.key, required this.existing, this.renaming});

  @override
  State<ClassNameDialog> createState() => _ClassNameDialogState();
}

class _ClassNameDialogState extends State<ClassNameDialog> {
  late final _name = TextEditingController(
    text: (widget.renaming?['classroomname'] ?? '').toString(),
  );
  String? _error;

  bool get _renaming => widget.renaming != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final error = _renaming
        ? validateClassRename(
            name: _name.text,
            currentForm: widget.renaming!['form'] as String,
            existing: widget.existing,
            editingClassId: widget.renaming!['classid'] as String,
          )
        : validateClassName(name: _name.text, existing: widget.existing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final form = formFromClassName(_name.text);
    return AlertDialog(
      title: Text(_renaming ? 'Rename class' : 'New class'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiField(
              label: 'Class name',
              child: TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Form 2B',
                  errorText: _error,
                  helperText: _renaming
                      ? 'Stays in ${formLevelLabel(widget.renaming!['form'] as String?)}. Students, subjects and teachers are kept.'
                      : form == null
                      ? 'Start with Form 1, 2, 3 or 4.'
                      : 'Follows the ${formLevelLabel(form)} calendar and fees.',
                  helperMaxLines: 2,
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_renaming ? 'Save name' : 'Create class'),
        ),
      ],
    );
  }
}

/// Pick subjects to link to a class. Subjects that are already linked are not
/// listed; unlinking is done per subject from Reassign.
class AddSubjectsDialog extends StatefulWidget {
  final String className;
  final List<Map<String, dynamic>> available;
  const AddSubjectsDialog({
    super.key,
    required this.className,
    required this.available,
  });

  @override
  State<AddSubjectsDialog> createState() => _AddSubjectsDialogState();
}

class _AddSubjectsDialogState extends State<AddSubjectsDialog> {
  final _chosen = <String>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add subjects to ${widget.className}'),
      content: SizedBox(
        width: 380,
        child: widget.available.isEmpty
            ? const Text(
                'Every subject in the catalogue is already linked to this class. Create a new subject under Academics to add more.',
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final subject in widget.available)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(subject['subjectname'] as String),
                        value: _chosen.contains(subject['subjectid']),
                        onChanged: (on) => setState(() {
                          final id = subject['subjectid'] as String;
                          on == true ? _chosen.add(id) : _chosen.remove(id);
                        }),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set.of(_chosen)),
          child: Text(
            _chosen.isEmpty
                ? 'Add subjects'
                : 'Add ${_chosen.length} subject${_chosen.length == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }
}

enum ReassignAction { change, remove, unlink }

/// What the Reassign dialog hands back.
class ReassignResult {
  final ReassignAction action;
  final String? staffId;
  final String? reason;
  const ReassignResult(this.action, {this.staffId, this.reason});
}

/// Change, remove or unlink the teacher of one subject in one class. Changing
/// and removing keep the old assignment as history.
class ReassignDialog extends StatefulWidget {
  final String subjectName;
  final String className;
  final String currentStaffId;
  final String currentName;

  /// Other teachers marked as teaching this subject.
  final List<Map<String, dynamic>> candidates;

  const ReassignDialog({
    super.key,
    required this.subjectName,
    required this.className,
    required this.currentStaffId,
    required this.currentName,
    required this.candidates,
  });

  @override
  State<ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<ReassignDialog> {
  final _reason = TextEditingController();
  ReassignAction _action = ReassignAction.change;
  String? _staffId;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_action == ReassignAction.change && _staffId == null) {
      setState(() => _error = 'Select the new teacher.');
      return;
    }
    final reasonError = validateReassignReason(_reason.text);
    if (reasonError != null) {
      setState(() => _error = reasonError);
      return;
    }
    final reason = _reason.text.trim();
    Navigator.of(context).pop(
      ReassignResult(
        _action,
        staffId: _action == ReassignAction.change ? _staffId : null,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  Widget _option({
    required ReassignAction action,
    required IconData icon,
    required String title,
    String? detail,
    Widget? body,
  }) {
    final selected = _action == action;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              _action = action;
              _error = null;
            }),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (detail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              detail,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        if (selected && body != null) ...[
                          const SizedBox(height: 8),
                          body,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reassign ${widget.subjectName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${widget.className} · currently ${widget.currentName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _option(
                action: ReassignAction.change,
                icon: Icons.swap_horiz_rounded,
                title: 'Change teacher',
                body: widget.candidates.isEmpty
                    ? const Text(
                        'No other teacher is marked as teaching this subject. Mark one on their staff profile first.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _staffId,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text('Select new teacher'),
                        items: [
                          for (final row in widget.candidates)
                            DropdownMenuItem(
                              value: row['staffid'] as String,
                              child: Text(
                                staffDisplayName(row),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) => setState(() {
                          _staffId = id;
                          _error = null;
                        }),
                      ),
              ),
              _option(
                action: ReassignAction.remove,
                icon: Icons.person_remove_outlined,
                title: 'Remove teacher',
                detail:
                    'The subject stays linked and goes back to Needs teacher.',
              ),
              _option(
                action: ReassignAction.unlink,
                icon: Icons.link_off_rounded,
                title: 'Unlink subject from class',
                detail:
                    'Removes ${widget.subjectName} and its teacher from ${widget.className}. Not possible once it has assessments or marks.',
              ),
              if (_action != ReassignAction.unlink) ...[
                const SizedBox(height: 4),
                UiField(
                  label: 'Reason (optional)',
                  child: TextField(
                    controller: _reason,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Teacher on leave',
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Confirm')),
      ],
    );
  }
}
