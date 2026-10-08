import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/auth/permission_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/can.dart';
import '../../data/grade_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _studentsForCsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      csId,
    ) async {
      // Get students currently enrolled in the class linked to this classsubject
      final cs = await supabase
          .from('classsubject')
          .select('classid, academicyearid')
          .eq('classsubjectid', csId)
          .single();

      final rows = await supabase
          .from('studentclasshistory')
          .select('student(studentid, firstname, lastname)')
          .eq('classid', cs['classid'] as String)
          .eq('academicyearid', cs['academicyearid'] as String)
          .isFilter('enddate', null); // still active
      return List<Map<String, dynamic>>.from(rows as List);
    });

final _existingGradesProvider =
    FutureProvider.family<Map<String, Map<String, dynamic>?>, String>((
      ref,
      assessmentId,
    ) async {
      final rows = await supabase
          .from('grade')
          .select()
          .eq('assessmentid', assessmentId);
      final map = <String, Map<String, dynamic>?>{};
      for (final r in rows as List) {
        map[r['studentid'] as String] = Map<String, dynamic>.from(r);
      }
      return map;
    });

// ── Page ──────────────────────────────────────────────────────────────────────

/// Grade entry / view page for one assessment.
/// Teachers enter scores; Head Teacher / Admin view them read-only.
class GradeEntryPage extends ConsumerStatefulWidget {
  final String assessmentId;
  final String assessmentName;
  final double maxScore;
  final String classSubjectId;
  final String className;
  final String subjectName;

  const GradeEntryPage({
    required this.assessmentId,
    required this.assessmentName,
    required this.maxScore,
    required this.classSubjectId,
    this.className = 'Class',
    this.subjectName = 'Subject',
    super.key,
  });

  @override
  ConsumerState<GradeEntryPage> createState() => _GradeEntryPageState();
}

class _GradeEntryPageState extends ConsumerState<GradeEntryPage> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _scoreFocusNodes = {};
  final Map<String, String> _statuses = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _focusedStudentIndex = 0;
  bool _saving = false;

  bool get _canEdit {
    final permHelper = ref.watch(permissionHelperProvider);
    return permHelper.maybeWhen(
      data: (perm) => perm?.canEnterGrades ?? false,
      orElse: () => false,
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final node in _scoreFocusNodes.values) {
      node.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _focusStudent(List<Map<String, dynamic>> students, int offset) {
    if (students.isEmpty) return;
    setState(() {
      _focusedStudentIndex = (_focusedStudentIndex + offset)
          .clamp(0, students.length - 1)
          .toInt();
    });
    final student =
        students[_focusedStudentIndex]['student'] as Map<String, dynamic>;
    final studentId = student['studentid'] as String;
    _scoreFocusNodes[studentId]?.requestFocus();
  }

  Future<void> _saveAll(
    List<Map<String, dynamic>> students,
    Map<String, Map<String, dynamic>?> existing,
    String staffId,
  ) async {
    setState(() => _saving = true);
    try {
      final repo = GradeRepository();
      for (final s in students) {
        final st = s['student'] as Map<String, dynamic>;
        final sid = st['studentid'] as String;
        final ctrl = _controllers[sid];
        if (ctrl == null) continue;
        final raw = ctrl.text.trim();
        double? score;
        try {
          score = raw.isEmpty ? null : validateScore(raw, widget.maxScore);
        } on FormatException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${st['firstname']} ${st['lastname']}: ${e.message}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _saving = false);
          return;
        }
        final status = _statuses[sid] ?? 'PRESENT';
        await repo.saveGrade(
          assessmentId: widget.assessmentId,
          studentId: sid,
          staffId: staffId,
          score: score,
          status: status,
        );
      }

      final actor = ref.read(authProvider).user!;
      await AuditService().log(
        userId: actor.userId,
        action: 'GRADES_SAVED',
        tableName: 'grade',
        recordId: widget.assessmentId,
        actorRole: actor.roleName,
        newValue: {'assessmentId': widget.assessmentId},
      );

      ref.invalidate(_existingGradesProvider(widget.assessmentId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grades saved successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(
      _studentsForCsProvider(widget.classSubjectId),
    );
    final gradesAsync = ref.watch(_existingGradesProvider(widget.assessmentId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.assessmentName),
            Text(
              '${widget.subjectName} · ${widget.className} · Out of ${widget.maxScore}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading students: $e')),
        data: (students) => gradesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading grades: $e')),
          data: (existing) {
            // Initialise controllers once
            for (final s in students) {
              final st = s['student'] as Map<String, dynamic>;
              final sid = st['studentid'] as String;
              if (!_controllers.containsKey(sid)) {
                final g = existing[sid];
                _controllers[sid] = TextEditingController(
                  text: g?['score']?.toString() ?? '',
                );
                _statuses[sid] = g?['gradestatus'] as String? ?? 'PRESENT';
                _scoreFocusNodes[sid] = FocusNode();
              }
            }

            if (students.isEmpty) {
              return const Center(
                child: Text(
                  'No students enrolled in this class.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final visibleStudents = students.where((row) {
              final student = row['student'] as Map<String, dynamic>;
              final name = '${student['firstname']} ${student['lastname']}'
                  .toLowerCase();
              return name.contains(_searchQuery.toLowerCase());
            }).toList();
            if (_focusedStudentIndex >= visibleStudents.length) {
              _focusedStudentIndex = visibleStudents.isEmpty
                  ? 0
                  : visibleStudents.length - 1;
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search students',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                // Header row
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Student',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(
                        width: 90,
                        child: Text(
                          'Score',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(
                        width: 110,
                        child: Text(
                          'Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: visibleStudents.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final st =
                          visibleStudents[i]['student'] as Map<String, dynamic>;
                      final sid = st['studentid'] as String;
                      final name = '${st['firstname']} ${st['lastname']}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name),
                                  Text(
                                    widget.className,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            // Score field
                            SizedBox(
                              width: 90,
                              child: _canEdit
                                  ? TextField(
                                      controller: _controllers[sid],
                                      focusNode: _scoreFocusNodes[sid],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                        border: const OutlineInputBorder(),
                                        hintText: '—',
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      _controllers[sid]?.text.isEmpty ?? true
                                          ? '—'
                                          : _controllers[sid]!.text,
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            // Status dropdown — reads/writes _statuses on the
                            // page state directly so scroll recycling can't
                            // lose the value.
                            SizedBox(
                              width: 110,
                              child: _canEdit
                                  ? DropdownButton<String>(
                                      value: _statuses[sid] ?? 'PRESENT',
                                      isDense: true,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'PRESENT',
                                          child: Text('Present'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'ABSENT',
                                          child: Text('Absent'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'MISSING',
                                          child: Text('Missing'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _statuses[sid] = v);
                                        }
                                      },
                                    )
                                  : Text(
                                      _statuses[sid] ?? '—',
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_canEdit && visibleStudents.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _focusedStudentIndex == 0
                              ? null
                              : () => _focusStudent(visibleStudents, -1),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Previous'),
                        ),
                        Expanded(
                          child: Text(
                            '${_focusedStudentIndex + 1} of ${visibleStudents.length}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _focusedStudentIndex >= visibleStudents.length - 1
                              ? null
                              : () => _focusStudent(visibleStudents, 1),
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Next'),
                        ),
                      ],
                    ),
                  ),
                if (_canEdit)
                  Can(
                    permission: 'grades:write',
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FutureBuilder<String>(
                        future: supabase
                            .from('staff')
                            .select('staffid')
                            .eq('userid', ref.read(authProvider).user!.userId)
                            .single()
                            .then((r) => r['staffid'] as String),
                        builder: (ctx, snap) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              onPressed: _saving || !snap.hasData
                                  ? null
                                  : () => _saveAll(
                                      students,
                                      existing,
                                      snap.data!,
                                    ),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('Save Draft Grades'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      await GradeRepository().submitAssessment(
                                        widget.assessmentId,
                                      );
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Grades submitted for progression.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.publish_outlined),
                              label: const Text('Submit Grades'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
