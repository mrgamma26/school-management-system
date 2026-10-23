import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permission_helper.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/rpc_error.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/can.dart';
import '../../../../widgets/ui_dialogs.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/assessment_repository.dart';
import '../../data/grade_repository.dart';
import '../../data/mark_workspace_repository.dart';
import '../../domain/mark_sheet.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

class _AssignmentsData {
  final String? staffId;
  final List<TeacherAssignment> assignments;
  const _AssignmentsData(this.staffId, this.assignments);
}

/// The signed-in teacher's staff id and their form-matched assignments.
final _assignmentsProvider = FutureProvider.autoDispose<_AssignmentsData>((
  ref,
) async {
  final userId = ref.watch(authProvider).user!.userId;
  final repo = MarkWorkspaceRepository();
  final staffId = await repo.staffIdForUser(userId);
  if (staffId == null) return const _AssignmentsData(null, []);
  return _AssignmentsData(staffId, await repo.assignments(staffId));
});

final _assessmentsProvider = FutureProvider.autoDispose
    .family<List<Assessment>, String>(
      (ref, classSubjectId) =>
          MarkWorkspaceRepository().assessmentsFor(classSubjectId),
    );

const _assessmentTypes = [
  'QUIZ',
  'TEST',
  'EXAM',
  'ASSIGNMENT',
  'PROJECT',
  'PRACTICAL',
  'END_OF_TERM',
];

enum _SaveState { idle, pending, saving, saved, error }

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ── Page ──────────────────────────────────────────────────────────────────────

/// Teacher "Enter marks" workspace (route `/assessments`, and the deep link
/// `/assessments/:assessmentId/grades`).
///
/// One page: pick an assigned class + subject, pick or create an assessment,
/// type marks into the roster (valid marks autosave as a draft), preview the
/// result sheet, and submit it to the Head Teacher.
class AssessmentsPage extends ConsumerStatefulWidget {
  /// When set (deep link), this assessment is opened once assignments load.
  final String? initialAssessmentId;

  const AssessmentsPage({super.key, this.initialAssessmentId});

  @override
  ConsumerState<AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends ConsumerState<AssessmentsPage> {
  static const _debounce = Duration(milliseconds: 700);

  // Selection.
  bool _bootstrapped = false;
  String? _staffId;
  String? _csId;
  Assessment? _assessment;
  int _tab = 0;

  // Notices.
  String? _flash;
  StatusTone _flashTone = StatusTone.success;

  // Inline "new assessment" form.
  bool _creating = false;
  bool _createBusy = false;
  String? _createError;
  final _newName = TextEditingController();
  final _newMax = TextEditingController();
  String _newType = 'TEST';

  // Loaded sheet.
  bool _sheetLoading = false;
  Object? _sheetError;
  int _loadToken = 0;
  List<RosterStudent> _roster = [];
  final Map<String, SavedGrade> _saved = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focus = {};
  final Map<String, bool> _absent = {};
  final _search = TextEditingController();
  String _query = '';

  // Autosave.
  final Set<String> _dirty = {};
  final Map<String, String> _saveErrors = {};
  _SaveState _saveState = _SaveState.idle;
  DateTime? _savedAt;
  Timer? _saveTimer;
  Future<void> _flushQueue = Future.value();
  bool _submitting = false;

  double get _max => _assessment?.maxScore ?? 0;

  bool get _canEdit => ref
      .watch(permissionHelperProvider)
      .maybeWhen(
        data: (perm) => perm?.canEnterGrades ?? false,
        orElse: () => false,
      );

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushDetached();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    _newName.dispose();
    _newMax.dispose();
    _search.dispose();
    super.dispose();
  }

  // ── Reading the sheet ──────────────────────────────────────────────────────

  MarkCheck _checkOf(String studentId) => checkMark(
    _controllers[studentId]?.text ?? '',
    _max,
    absent: _absent[studentId] ?? false,
  );

  SheetStats get _stats =>
      computeSheetStats(_roster.map((s) => _checkOf(s.studentId)), _max);

  SheetLifecycle get _lifecycle => lifecycleOf(
    _saved.values.map((g) => (submitted: g.submitted, published: g.published)),
  );

  // ── Selection ──────────────────────────────────────────────────────────────

  Future<void> _bootstrap(_AssignmentsData data) async {
    _staffId = data.staffId;
    String? classSubjectId;
    String? assessmentId;
    final deepLink = widget.initialAssessmentId;
    if (deepLink != null) {
      try {
        final target = await MarkWorkspaceRepository().assessmentById(deepLink);
        if (target != null &&
            data.assignments.any(
              (a) => a.classSubjectId == target.classSubjectId,
            )) {
          classSubjectId = target.classSubjectId;
          assessmentId = target.id;
        } else if (mounted) {
          _setFlash(
            'That assessment is not one of your assignments, so it was not opened.',
            StatusTone.warning,
          );
        }
      } catch (_) {
        if (mounted) {
          _setFlash('Could not open that assessment.', StatusTone.warning);
        }
      }
    }
    classSubjectId ??= data.assignments.first.classSubjectId;
    await _selectAssignment(
      classSubjectId,
      preferredAssessmentId: assessmentId,
    );
  }

  void _setFlash(String? text, [StatusTone tone = StatusTone.success]) {
    if (!mounted) return;
    setState(() {
      _flash = text;
      _flashTone = tone;
    });
  }

  Future<void> _selectAssignment(
    String classSubjectId, {
    String? preferredAssessmentId,
  }) async {
    await _flushNow();
    if (!mounted) return;
    _loadToken++;
    setState(() {
      _csId = classSubjectId;
      _assessment = null;
      _tab = 0;
      _creating = false;
      _createError = null;
      _resetSheet();
    });
    try {
      final list = await ref.read(_assessmentsProvider(classSubjectId).future);
      if (!mounted || _csId != classSubjectId) return;
      Assessment? pick;
      for (final a in list) {
        if (a.id == preferredAssessmentId) pick = a;
      }
      pick ??= list.isEmpty ? null : list.last;
      if (pick == null) {
        setState(() => _creating = true);
        return;
      }
      await _openAssessment(pick);
    } catch (e) {
      if (mounted && _csId == classSubjectId) {
        _setFlash(friendlyError(e), StatusTone.danger);
      }
    }
  }

  Future<void> _chooseAssessment(Assessment assessment) async {
    if (assessment.id == _assessment?.id) return;
    await _flushNow();
    if (!mounted) return;
    setState(() => _flash = null);
    await _openAssessment(assessment);
  }

  Future<void> _openAssessment(Assessment assessment) async {
    final token = ++_loadToken;
    setState(() {
      _assessment = assessment;
      _tab = 0;
      _creating = false;
      _sheetLoading = true;
      _sheetError = null;
      _resetSheet();
    });
    try {
      final repo = MarkWorkspaceRepository();
      final rosterFuture = repo.roster(assessment.classSubjectId);
      final gradesFuture = repo.grades(assessment.id);
      final loaded = await Future.wait<Object>([rosterFuture, gradesFuture]);
      if (!mounted || token != _loadToken) return;
      final roster = loaded[0] as List<RosterStudent>;
      final grades = loaded[1] as List<SavedGrade>;
      setState(() {
        _roster = roster;
        for (final g in grades) {
          _saved[g.studentId] = g;
        }
        for (final s in roster) {
          final g = _saved[s.studentId];
          _controllers[s.studentId] = TextEditingController(
            text: g?.score == null ? '' : formatScore(g!.score!),
          );
          _absent[s.studentId] = g?.status.toUpperCase() == 'ABSENT';
          _focus[s.studentId] = FocusNode();
        }
        _sheetLoading = false;
      });
    } catch (e) {
      if (mounted && token == _loadToken) {
        setState(() {
          _sheetLoading = false;
          _sheetError = e;
        });
      }
    }
  }

  /// Forgets the loaded sheet. The controllers are disposed after the frame
  /// that stops using them.
  void _resetSheet() {
    final oldControllers = _controllers.values.toList();
    final oldFocus = _focus.values.toList();
    _controllers.clear();
    _focus.clear();
    _absent.clear();
    _saved.clear();
    _dirty.clear();
    _saveErrors.clear();
    _roster = [];
    _saveState = _SaveState.idle;
    _savedAt = null;
    _query = '';
    _search.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in oldControllers) {
        c.dispose();
      }
      for (final f in oldFocus) {
        f.dispose();
      }
    });
  }

  Future<void> _reloadGrades() async {
    final assessment = _assessment;
    if (assessment == null) return;
    final grades = await MarkWorkspaceRepository().grades(assessment.id);
    if (!mounted || _assessment?.id != assessment.id) return;
    setState(() {
      _saved
        ..clear()
        ..addEntries(grades.map((g) => MapEntry(g.studentId, g)));
    });
  }

  // ── Autosave ───────────────────────────────────────────────────────────────

  void _markChanged(String studentId) {
    _dirty.add(studentId);
    _saveErrors.remove(studentId);
    setState(() => _saveState = _SaveState.pending);
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, _flushNow);
  }

  void _toggleAbsent(String studentId) {
    final next = !(_absent[studentId] ?? false);
    if (next) _controllers[studentId]?.clear();
    _absent[studentId] = next;
    _markChanged(studentId);
  }

  void _focusNext(List<RosterStudent> order, String studentId) {
    final i = order.indexWhere((s) => s.studentId == studentId);
    if (i < 0) return;
    for (var j = i + 1; j < order.length; j++) {
      final node = _focus[order[j].studentId];
      if (node != null && node.context != null) {
        node.requestFocus();
        return;
      }
    }
  }

  /// What would be written right now: valid marks, absences, and cleared marks
  /// that already have a stored row. Invalid text is flagged and never written.
  List<({String studentId, double? score, String status})> _pendingWrites() {
    final writes = <({String studentId, double? score, String status})>[];
    for (final id in _dirty) {
      if (_saved[id]?.published ?? false) continue;
      final check = _checkOf(id);
      switch (check.state) {
        case MarkState.valid:
          writes.add((studentId: id, score: check.score, status: 'PRESENT'));
        case MarkState.absent:
          writes.add((studentId: id, score: null, status: 'ABSENT'));
        case MarkState.missing:
          if (_saved.containsKey(id)) {
            writes.add((studentId: id, score: null, status: 'MISSING'));
          }
        case MarkState.invalid:
          break;
      }
    }
    return writes;
  }

  /// Saves everything pending now (and after any save already running).
  Future<void> _flushNow() {
    _saveTimer?.cancel();
    return _flushQueue = _flushQueue.then((_) => _doFlush());
  }

  Future<void> _doFlush() async {
    final assessment = _assessment;
    final staffId = _staffId;
    if (assessment == null || staffId == null || _dirty.isEmpty) return;
    final writes = _pendingWrites();
    _dirty.clear();
    if (writes.isEmpty) {
      if (mounted) {
        setState(
          () => _saveState = _savedAt == null
              ? _SaveState.idle
              : _SaveState.saved,
        );
      }
      return;
    }
    if (mounted) setState(() => _saveState = _SaveState.saving);
    final repo = GradeRepository();
    var failed = 0;
    for (final w in writes) {
      try {
        await repo.saveGrade(
          assessmentId: assessment.id,
          studentId: w.studentId,
          staffId: staffId,
          score: w.score,
          status: w.status,
        );
        _saved[w.studentId] = SavedGrade(
          gradeId: _saved[w.studentId]?.gradeId,
          studentId: w.studentId,
          score: w.score,
          status: w.status,
          submitted: false,
        );
        _saveErrors.remove(w.studentId);
      } catch (e) {
        failed++;
        _dirty.add(w.studentId);
        _saveErrors[w.studentId] = friendlyError(e);
      }
    }
    if (!mounted) return;
    setState(() {
      if (failed > 0) {
        _saveState = _SaveState.error;
      } else if (_dirty.isNotEmpty) {
        _saveState = _SaveState.pending;
      } else {
        _saveState = _SaveState.saved;
        _savedAt = DateTime.now();
      }
    });
  }

  /// Best-effort save when the page closes with unsaved edits.
  void _flushDetached() {
    final assessment = _assessment;
    final staffId = _staffId;
    if (assessment == null || staffId == null || _dirty.isEmpty) return;
    final writes = _pendingWrites();
    if (writes.isEmpty) return;
    final repo = GradeRepository();
    unawaited(() async {
      for (final w in writes) {
        try {
          await repo.saveGrade(
            assessmentId: assessment.id,
            studentId: w.studentId,
            staffId: staffId,
            score: w.score,
            status: w.status,
          );
        } catch (_) {
          // The page is gone; nothing to tell the user here.
        }
      }
    }());
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _createAssessment() async {
    final csId = _csId;
    if (csId == null || _createBusy) return;
    final name = _newName.text.trim();
    final max = double.tryParse(_newMax.text.trim());
    if (name.isEmpty || max == null || max <= 0) {
      setState(
        () => _createError =
            'Enter an assessment title and a maximum mark '
            'above zero.',
      );
      return;
    }
    await _flushNow();
    if (!mounted) return;
    setState(() {
      _createBusy = true;
      _createError = null;
    });
    try {
      final created = await AssessmentRepository().createAssessment(
        classSubjectId: csId,
        name: name,
        type: _newType,
        maxScore: max,
      );
      ref.invalidate(_assessmentsProvider(csId));
      _newName.clear();
      _newMax.clear();
      if (!mounted) return;
      setState(() => _createBusy = false);
      await _openAssessment(created);
      _setFlash(
        'Assessment "${created.name}" created. Enter marks below; valid '
        'marks save automatically as a draft.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _createBusy = false;
          _createError = e is AppException
              ? e.message
              : 'Could not create the assessment. Please try again.';
        });
      }
    }
  }

  Future<void> _submit() async {
    final assessment = _assessment;
    final assignment = _assignment();
    if (assessment == null || _submitting) return;
    await _flushNow();
    if (!mounted) return;
    final stats = _stats;
    if (_dirty.isNotEmpty || _saveErrors.isNotEmpty) {
      _setFlash(
        'Some marks could not be saved yet. Use Retry, then submit.',
        StatusTone.danger,
      );
      return;
    }
    if (!stats.ready) {
      _setFlash(
        'Complete or fix every mark before submitting '
        '(${stats.missing} missing, ${stats.invalid} flagged).',
        StatusTone.warning,
      );
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Submit to Head Teacher',
      message:
          'Submit ${assignment?.label ?? 'this sheet'} - ${assessment.name} '
          'to the Head Teacher? ${stats.valid} mark(s) entered'
          '${stats.absent > 0 ? ' and ${stats.absent} absent' : ''}. After '
          'submission the marks become read-only. Changes after publication '
          'need a Head Teacher-approved correction.',
      confirmLabel: 'Yes, submit',
    );
    if (!confirmed || !mounted) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await GradeRepository().submitAssessment(assessment.id);
      await _reloadGrades();
      final actor = ref.read(authProvider).user;
      if (actor != null) {
        try {
          await AuditService().log(
            userId: actor.userId,
            action: 'GRADES_SUBMITTED',
            tableName: 'grade',
            recordId: assessment.id,
            actorRole: actor.roleName,
            newValue: {'assessmentId': assessment.id, 'marks': stats.valid},
          );
        } catch (_) {
          // The audit entry is best effort; the submission itself succeeded.
        }
      }
      _setFlash(
        '${assignment?.label ?? 'Sheet'} - ${assessment.name} submitted to '
        'the Head Teacher. Marks are now read-only.',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(rpcErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestCorrection(RosterStudent student, SavedGrade g) async {
    final gradeId = g.gradeId;
    if (gradeId == null) return;
    final reason = await showReasonDialog(
      context,
      title: 'Request correction',
      message:
          'Ask the Head Teacher to approve a change to ${student.name}\'s '
          'published mark. Once approved you can enter the corrected score.',
      confirmLabel: 'Send request',
      label: 'Reason for the correction',
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await GradeRepository().requestCorrection(
        gradeId: gradeId,
        reason: reason,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Correction request sent.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(rpcErrorMessage(e))));
    }
  }

  Future<void> _exportPdf(
    List<RankedMark> ranked,
    List<RosterStudent> others,
    SheetStats stats,
  ) async {
    final assessment = _assessment;
    if (assessment == null) return;
    final assignment = _assignment();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExportService.exportToPdf(
        title: '${assessment.name} result sheet',
        subtitle:
            '${assignment?.label ?? ''} · ${assignment?.periodLabel ?? ''}',
        headers: const ['Pos.', 'Student', 'Mark', '%', 'Grade'],
        rows: [
          for (final r in ranked)
            [
              '${r.position}',
              r.name,
              '${formatScore(r.score)}/${formatScore(assessment.maxScore)}',
              formatScore(r.percent),
              r.grade,
            ],
          for (final s in others)
            [
              '-',
              s.name,
              _absent[s.studentId] ?? false ? 'Absent' : 'Missing',
              '-',
              '-',
            ],
        ],
        footer:
            'Average ${stats.averagePercent == null ? '-' : '${formatScore(stats.averagePercent!)}%'}'
            ' · Highest ${stats.highest == null ? '-' : formatScore(stats.highest!)}'
            ' · Pass rate ${stats.passRatePercent == null ? '-' : '${stats.passRatePercent}%'}'
            '${_lifecycle == SheetLifecycle.draft ? ' · Draft, not yet submitted' : ''}',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  TeacherAssignment? _assignment() {
    final data = ref.read(_assignmentsProvider).value;
    if (data == null) return null;
    for (final a in data.assignments) {
      if (a.classSubjectId == _csId) return a;
    }
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_assignmentsProvider);
    return PageFrame(
      kicker: 'Assessments',
      title: 'Enter marks',
      subtitle:
          'Pick a class and subject, choose or create an assessment, then '
          'type marks. Valid marks save automatically as a draft.',
      actions: [
        UiButton.secondary(
          'Correction requests',
          icon: Icons.rule_outlined,
          onPressed: () => context.go('/results/corrections'),
        ),
        UiButton.secondary(
          'Teacher comments',
          icon: Icons.comment_outlined,
          onPressed: () => context.go('/teacher/comments'),
        ),
      ],
      body: async.when(
        loading: () => const LoadingState(message: 'Loading your classes…'),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_assignmentsProvider),
        ),
        data: _workspace,
      ),
    );
  }

  Widget _workspace(_AssignmentsData data) {
    if (data.staffId == null) {
      return const UiCard(
        child: UiEmptyState(
          icon: Icons.badge_outlined,
          title: 'No staff profile',
          message:
              'Your account is not linked to a staff record, so no classes '
              'can be assigned to you.',
        ),
      );
    }
    if (data.assignments.isEmpty) {
      return const UiCard(
        child: UiEmptyState(
          icon: Icons.assignment_ind_outlined,
          title: 'No class assignments yet',
          message:
              'No class assignments match a form-specific academic period.',
        ),
      );
    }
    if (!_bootstrapped) {
      _bootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bootstrap(data);
      });
    }
    if (_csId == null) {
      return const LoadingState(message: 'Opening your marks…');
    }

    final canEdit = _canEdit;
    final assessments = ref.watch(_assessmentsProvider(_csId!));
    final assessment = _assessment;
    final stats = assessment == null || _sheetLoading ? null : _stats;
    final life = _lifecycle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pickBar(data, assessments, canEdit),
                if (_flash != null)
                  UiNotice(
                    _flash!,
                    tone: _flashTone,
                    icon: _flashTone == StatusTone.success
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                  ),
                if (_creating && canEdit) _newForm(),
                const SizedBox(height: 14),
                if (assessment == null)
                  _noAssessment(canEdit)
                else
                  SplitLayout(
                    main: _mainColumn(assessment, stats, life, canEdit),
                    side: _sidePanel(assessment, stats, life),
                  ),
              ],
            ),
          ),
        ),
        if (assessment != null && stats != null && !_sheetLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _footer(stats, life, canEdit),
          ),
      ],
    );
  }

  // ── Picker bar ─────────────────────────────────────────────────────────────

  Widget _pickBar(
    _AssignmentsData data,
    AsyncValue<List<Assessment>> assessments,
    bool canEdit,
  ) {
    final list = assessments.value ?? const <Assessment>[];
    final selected = list.any((a) => a.id == _assessment?.id)
        ? _assessment!.id
        : null;
    // Marks can be entered for any term of the year: pick the term first,
    // then the class and subject taught in that term.
    final current = _assignment();
    final terms = <String>{
      for (final a in data.assignments) a.periodLabel,
    }.toList()..sort();
    final term = current?.periodLabel;
    final inTerm = [
      for (final a in data.assignments)
        if (term == null || a.periodLabel == term) a,
    ];
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveGrid(
            columns: 3,
            mediumColumns: 2,
            phoneColumns: 1,
            children: [
              UiField(
                label: 'Term',
                child: DropdownButtonFormField<String>(
                  key: ValueKey('term-$term'),
                  initialValue: term,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final t in terms)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) {
                    if (v == null || v == term) return;
                    final options = data.assignments
                        .where((a) => a.periodLabel == v)
                        .toList();
                    final same = options.where(
                      (a) => a.label == current?.label,
                    );
                    final next = same.isNotEmpty ? same.first : options.first;
                    _selectAssignment(next.classSubjectId);
                  },
                ),
              ),
              UiField(
                label: 'Class and subject',
                child: DropdownButtonFormField<String>(
                  key: ValueKey('cs-$_csId'),
                  initialValue: _csId,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final a in inTerm)
                      DropdownMenuItem(
                        value: a.classSubjectId,
                        child: Text(a.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null && v != _csId) _selectAssignment(v);
                  },
                ),
              ),
              UiField(
                label: 'Assessment',
                child: DropdownButtonFormField<String>(
                  key: ValueKey('as-$_csId-$selected-${list.length}'),
                  initialValue: selected,
                  isExpanded: true,
                  hint: Text(
                    assessments.isLoading
                        ? 'Loading…'
                        : list.isEmpty
                        ? 'No assessments yet'
                        : 'Choose an assessment',
                  ),
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final a in list)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.name} (${formatScore(a.maxScore)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    for (final a in list) {
                      if (a.id == v) _chooseAssessment(a);
                    }
                  },
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Save status'),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _saveStatus(),
                  ),
                ],
              ),
            ],
          ),
          if (canEdit)
            Can(
              permission: 'assessments:write',
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: UiButton.secondary(
                    _creating ? 'Close new assessment' : 'New assessment',
                    icon: _creating ? Icons.close_rounded : Icons.add_rounded,
                    onPressed: () => setState(() {
                      _creating = !_creating;
                      _createError = null;
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _saveStatus() {
    final invalid = _assessment == null || _sheetLoading ? 0 : _stats.invalid;
    final (IconData icon, Color color, String text) = switch (_saveState) {
      _SaveState.saving => (
        Icons.sync_rounded,
        AppColors.textSecondary,
        'Saving…',
      ),
      _SaveState.pending => (
        Icons.edit_note_rounded,
        AppColors.warning,
        'Unsaved changes…',
      ),
      _SaveState.saved => (
        Icons.check_circle_outline,
        AppColors.success,
        'Saved ${_savedAt == null ? '' : _hhmm(_savedAt!)}'.trim(),
      ),
      _SaveState.error => (
        Icons.error_outline,
        AppColors.danger,
        'Could not save ${_saveErrors.length} mark(s)',
      ),
      _SaveState.idle => (
        Icons.cloud_done_outlined,
        AppColors.textSecondary,
        'Autosave on',
      ),
    };
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(icon, size: 17, color: color),
        Text(
          invalid > 0 ? '$text · $invalid flagged, not saved' : text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: invalid > 0 && _saveState != _SaveState.error
                ? AppColors.danger
                : color,
          ),
        ),
        if (_saveState == _SaveState.error)
          InkWell(
            onTap: _flushNow,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _newForm() {
    final assignment = _assignment();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: FormPanel(
        title: 'New assessment for ${assignment?.label ?? 'this class'}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldGrid(
              children: [
                UiField(
                  label: 'Title *',
                  child: TextField(
                    controller: _newName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Chapter 6 Quiz',
                    ),
                  ),
                ),
                UiField(
                  label: 'Type',
                  child: DropdownButtonFormField<String>(
                    initialValue: _newType,
                    isExpanded: true,
                    items: [
                      for (final t in _assessmentTypes)
                        DropdownMenuItem(
                          value: t,
                          child: Text(t.replaceAll('_', ' ')),
                        ),
                    ],
                    onChanged: (v) => setState(() => _newType = v ?? 'TEST'),
                  ),
                ),
                UiField(
                  label: 'Maximum mark *',
                  child: TextField(
                    controller: _newMax,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSubmitted: (_) => _createAssessment(),
                    decoration: const InputDecoration(hintText: 'e.g. 100'),
                  ),
                ),
              ],
            ),
            if (_createError != null) UiNotice(_createError!),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                UiButton(
                  _createBusy ? 'Creating…' : 'Create and enter marks',
                  icon: Icons.check_rounded,
                  onPressed: _createBusy ? null : _createAssessment,
                ),
                UiButton.secondary(
                  'Cancel',
                  onPressed: _createBusy
                      ? null
                      : () => setState(() {
                          _creating = false;
                          _createError = null;
                        }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _noAssessment(bool canEdit) {
    return UiCard(
      child: UiEmptyState(
        icon: Icons.quiz_outlined,
        title: 'No assessment selected',
        message: canEdit
            ? 'Create an assessment for this class and subject to start '
                  'entering marks.'
            : 'There are no assessments for this class and subject yet.',
      ),
    );
  }

  // ── Main column ────────────────────────────────────────────────────────────

  Widget _mainColumn(
    Assessment assessment,
    SheetStats? stats,
    SheetLifecycle life,
    bool canEdit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (life == SheetLifecycle.submitted)
          const UiNotice(
            'Submitted to the Head Teacher. Marks are read-only until the '
            'Head Teacher publishes them.',
            tone: StatusTone.success,
            icon: Icons.lock_outline,
          ),
        if (life == SheetLifecycle.published)
          UiNotice(
            'Published and locked. To change a mark, request a correction; '
            'the Head Teacher approves it first.',
            tone: StatusTone.info,
            icon: Icons.verified_outlined,
          ),
        TabsBar(
          tabs: const ['Enter marks', 'Result sheet preview'],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        if (_sheetLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading students and marks…'),
          )
        else if (_sheetError != null)
          ErrorState(
            error: _sheetError!,
            onRetry: () {
              final a = _assessment;
              if (a != null) _openAssessment(a);
            },
          )
        else if (_roster.isEmpty)
          const UiCard(
            child: UiEmptyState(
              icon: Icons.groups_outlined,
              title: 'No students enrolled',
              message: 'No students are enrolled in this class and subject.',
            ),
          )
        else if (_tab == 0)
          _marksTab(assessment, life, canEdit)
        else
          _previewTab(assessment, stats ?? _stats, life),
      ],
    );
  }

  Widget _marksTab(Assessment assessment, SheetLifecycle life, bool canEdit) {
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.mobile;
    final q = _query.trim().toLowerCase();
    final visible = [
      for (final s in _roster)
        if (q.isEmpty || s.name.toLowerCase().contains(q)) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiToolbar(
          searchHint: 'Search students',
          controller: _search,
          onSearch: (v) => setState(() => _query = v),
          trailing: [
            StatusPill('${_roster.length} students', tone: StatusTone.info),
            StatusPill('Out of ${formatScore(assessment.maxScore)}'),
          ],
        ),
        DataTableCard(
          columns: [
            const UiColumn('Student', flex: 14),
            UiColumn('Mark / ${formatScore(assessment.maxScore)}', width: 118),
            const UiColumn('%', width: 64, hideOnPhone: true),
            const UiColumn('Grade', width: 60, hideOnPhone: true),
            const UiColumn('Status', width: 150, hideOnPhone: true),
            const UiColumn('', width: 44),
          ],
          rows: [
            for (final s in visible)
              _studentRow(s, visible, life, canEdit, phone),
          ],
          empty: const UiEmptyState(
            icon: Icons.search_off,
            title: 'No matching students',
          ),
        ),
      ],
    );
  }

  UiTableRow _studentRow(
    RosterStudent s,
    List<RosterStudent> order,
    SheetLifecycle life,
    bool canEdit,
    bool phone,
  ) {
    final id = s.studentId;
    final check = _checkOf(id);
    final saved = _saved[id];
    final rowPublished = saved?.published ?? false;
    final editable = canEdit && life == SheetLifecycle.draft && !rowPublished;
    final absent = _absent[id] ?? false;
    final percent = check.isValid && _max > 0
        ? check.score! / _max * 100
        : null;

    final (String statusText, StatusTone tone) = _saveErrors.containsKey(id)
        ? ('Not saved', StatusTone.danger)
        : rowPublished
        ? ('Published', StatusTone.success)
        : switch (check.state) {
            MarkState.valid => ('Valid', StatusTone.success),
            MarkState.absent => ('Absent', StatusTone.neutral),
            MarkState.missing => ('Missing', StatusTone.warning),
            MarkState.invalid => (
              check.message ?? 'Invalid',
              StatusTone.danger,
            ),
          };

    final Widget markCell = editable
        ? SizedBox(
            height: 40,
            child: TextField(
              controller: _controllers[id],
              focusNode: _focus[id],
              enabled: !absent,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              textAlign: TextAlign.center,
              onChanged: (_) => _markChanged(id),
              onSubmitted: (_) => _focusNext(order, id),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true,
                hintText: absent ? 'Absent' : '—',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                enabledBorder: check.state == MarkState.invalid
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.danger),
                      )
                    : null,
                focusedBorder: check.state == MarkState.invalid
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.danger,
                          width: 2,
                        ),
                      )
                    : null,
              ),
            ),
          )
        : Text(
            absent
                ? 'Absent'
                : (_controllers[id]?.text.isEmpty ?? true)
                ? '—'
                : _controllers[id]!.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          );

    final Widget action;
    if (rowPublished && canEdit && saved?.gradeId != null) {
      action = IconButton(
        tooltip: 'Request correction',
        iconSize: 19,
        onPressed: () => _requestCorrection(s, saved!),
        icon: const Icon(Icons.rule_outlined),
      );
    } else if (editable) {
      action = IconButton(
        tooltip: absent ? 'Mark present' : 'Mark absent',
        iconSize: 19,
        onPressed: () => _toggleAbsent(id),
        icon: Icon(absent ? Icons.person_outline : Icons.person_off_outlined),
      );
    } else {
      action = const SizedBox.shrink();
    }

    return UiTableRow([
      PersonCell(s.name, subtitle: phone ? statusText : null),
      markCell,
      UiCellText(percent == null ? '—' : formatScore(_round1(percent))),
      UiCellText(percent == null ? '—' : gradeLetter(percent), bold: true),
      Align(
        alignment: Alignment.centerLeft,
        child: StatusPill(statusText, tone: tone),
      ),
      action,
    ]);
  }

  static double _round1(double v) => (v * 10).roundToDouble() / 10;

  // ── Preview tab ────────────────────────────────────────────────────────────

  Widget _previewTab(
    Assessment assessment,
    SheetStats stats,
    SheetLifecycle life,
  ) {
    final valid = <({String studentId, String name, double score})>[];
    final others = <RosterStudent>[];
    for (final s in _roster) {
      final check = _checkOf(s.studentId);
      if (check.isValid) {
        valid.add((studentId: s.studentId, name: s.name, score: check.score!));
      } else {
        others.add(s);
      }
    }
    final ranked = rankMarks(valid, assessment.maxScore);
    final assignment = _assignment();
    final avg = stats.averagePercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiNotice(
          life == SheetLifecycle.draft
              ? 'Preview from the marks on screen. This is a draft; nothing '
                    'is shared until the Head Teacher publishes it.'
              : 'Result sheet for ${assignment?.label ?? 'this class'}.',
          tone: StatusTone.info,
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          columns: 4,
          mediumColumns: 2,
          phoneColumns: 2,
          children: [
            MetricCard(
              icon: Icons.edit_note_outlined,
              label: 'Entered',
              value: '${stats.valid} of ${stats.total}',
              note: stats.absent > 0 ? '${stats.absent} absent' : null,
              noteTone: StatusTone.neutral,
            ),
            MetricCard(
              icon: Icons.functions_rounded,
              label: 'Average',
              value: avg == null ? '—' : '${formatScore(avg)}%',
              noteTone: StatusTone.neutral,
            ),
            MetricCard(
              icon: Icons.arrow_upward_rounded,
              label: 'Highest / lowest',
              value: stats.highest == null
                  ? '—'
                  : '${formatScore(stats.highest!)} / ${formatScore(stats.lowest!)}',
              noteTone: StatusTone.neutral,
            ),
            MetricCard(
              icon: Icons.verified_outlined,
              label: 'Pass rate',
              value: stats.passRatePercent == null
                  ? '—'
                  : '${stats.passRatePercent}%',
              note: 'At or above 50%',
              noteTone: StatusTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: 14),
        DataTableCard(
          columns: const [
            UiColumn('Pos.', width: 52),
            UiColumn('Student', flex: 14),
            UiColumn('Mark', width: 90),
            UiColumn('%', width: 60, hideOnPhone: true),
            UiColumn('Grade', width: 60),
          ],
          rows: [
            for (final r in ranked)
              UiTableRow([
                UiCellText('${r.position}', bold: true),
                UiCellText(r.name),
                UiCellText(
                  '${formatScore(r.score)}/${formatScore(assessment.maxScore)}',
                ),
                UiCellText(formatScore(r.percent)),
                UiCellText(r.grade, bold: true),
              ]),
            for (final s in others)
              UiTableRow([
                const UiCellText('—'),
                UiCellText(s.name),
                UiCellText(
                  (_absent[s.studentId] ?? false)
                      ? 'Absent'
                      : _checkOf(s.studentId).state == MarkState.invalid
                      ? 'Invalid'
                      : 'Missing',
                ),
                const UiCellText('—'),
                const UiCellText('—'),
              ]),
          ],
          empty: const UiEmptyState(
            icon: Icons.list_alt_outlined,
            title: 'No valid marks yet',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            UiButton(
              'Print / save PDF',
              icon: Icons.print_outlined,
              onPressed: ranked.isEmpty && others.isEmpty
                  ? null
                  : () => _exportPdf(ranked, others, stats),
            ),
            UiButton.secondary(
              'Back to marks',
              icon: Icons.edit_outlined,
              onPressed: () => setState(() => _tab = 0),
            ),
          ],
        ),
      ],
    );
  }

  // ── Side panel & footer ────────────────────────────────────────────────────

  Widget _sidePanel(
    Assessment assessment,
    SheetStats? stats,
    SheetLifecycle life,
  ) {
    final assignment = _assignment();
    final (String lifeText, StatusTone lifeTone) = switch (life) {
      SheetLifecycle.draft => ('Draft', StatusTone.info),
      SheetLifecycle.submitted => ('Submitted', StatusTone.warning),
      SheetLifecycle.published => ('Published', StatusTone.success),
    };
    return Panel(
      title: assignment?.label ?? 'Assessment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailLine(
            'Assessment',
            '${assessment.name} (${formatScore(assessment.maxScore)})',
          ),
          DetailLine('Type', assessment.type.replaceAll('_', ' ')),
          DetailLine('Period', assignment?.periodLabel ?? '—'),
          DetailLine('Students', stats == null ? '…' : '${stats.total}'),
          DetailLine('Status', lifeText, valueColor: lifeTone.foreground),
          const InlineGuide(
            title: 'Rules in force.',
            text:
                'You see only your own current assignments. Marks run from 0 '
                'to the maximum; valid marks save as a draft while you type '
                'and flagged marks are not saved. Only the Head Teacher or '
                'Super User publishes. A published mark changes only through '
                'an approved correction request.',
          ),
        ],
      ),
    );
  }

  Widget _footer(SheetStats stats, SheetLifecycle life, bool canEdit) {
    final canSubmit = canEdit && life == SheetLifecycle.draft;
    final blocker = !canSubmit
        ? null
        : stats.invalid > 0
        ? '${stats.invalid} flagged'
        : stats.missing > 0
        ? '${stats.missing} missing'
        : null;
    return UiCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 16,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stats.accounted} of ${stats.total} marks complete'
                '${blocker == null ? '' : ' · $blocker'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stats.completion,
                    minHeight: 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_tab == 0)
                UiButton.secondary(
                  'Preview result sheet',
                  icon: Icons.description_outlined,
                  onPressed: () => setState(() => _tab = 1),
                )
              else
                UiButton.secondary(
                  'Back to marks',
                  icon: Icons.edit_outlined,
                  onPressed: () => setState(() => _tab = 0),
                ),
              if (canEdit)
                UiButton(
                  switch (life) {
                    SheetLifecycle.published => 'Published',
                    SheetLifecycle.submitted => 'Submitted',
                    SheetLifecycle.draft =>
                      _submitting ? 'Submitting…' : 'Submit to Head Teacher',
                  },
                  icon: Icons.send_outlined,
                  onPressed: canSubmit && stats.ready && !_submitting
                      ? _submit
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
