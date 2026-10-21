import 'package:flutter/material.dart';
import '../../../core/widgets/app_widgets.dart' show ErrorState, LoadingState;
import '../../../theme/app_tokens.dart';
import '../../../widgets/ui_kit.dart';
import '../data/student_repository.dart';

class StudentSubjectsPage extends StatefulWidget {
  final String studentId;
  const StudentSubjectsPage({required this.studentId, super.key});

  @override
  State<StudentSubjectsPage> createState() => _StudentSubjectsPageState();
}

class _StudentSubjectsPageState extends State<StudentSubjectsPage> {
  final _repository = StudentRepository();
  List<Map<String, dynamic>> _selected = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.getStudentSubjects(widget.studentId),
        _repository.listSubjectAssignments(),
      ]);
      if (mounted) {
        setState(() {
          _selected = results[0];
          _assignments = results[1];
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _assignmentLabel(Map<String, dynamic> assignment) {
    final subject = assignment['subject'] as Map<String, dynamic>?;
    final staff = assignment['staff'] as Map<String, dynamic>?;
    final classroom = assignment['class'] as Map<String, dynamic>?;
    final teacher = staff == null
        ? 'Unassigned teacher'
        : '${staff['firstname']} ${staff['lastname']}';
    return '${subject?['subjectname'] ?? 'Subject'} · $teacher'
        '${classroom == null ? '' : ' · ${classroom['classroomname']}'}';
  }

  Future<void> _add() async {
    final linkedIds = _selected
        .map((row) => row['classsubjectid'] as String)
        .toSet();
    final choices = _assignments
        .where((row) => !linkedIds.contains(row['classsubjectid']))
        .toList();
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available subject assignments are added.'),
        ),
      );
      return;
    }
    String? selectedId;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Subject'),
          content: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Subject and teacher'),
            items: choices
                .map(
                  (row) => DropdownMenuItem(
                    value: row['classsubjectid'] as String,
                    child: Text(_assignmentLabel(row)),
                  ),
                )
                .toList(),
            onChanged: (value) => setDialogState(() => selectedId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedId),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (selectedId == null) return;
    await _repository.addStudentSubject(
      studentId: widget.studentId,
      classSubjectId: selectedId!,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return UiPage(
      children: [
        PageHead(
          kicker: 'Students',
          title: 'Student Subjects',
          subtitle: 'Individual subject enrolments for this learner.',
          actions: [
            UiButton(
              'Add Subject',
              icon: Icons.add_rounded,
              onPressed: _loading ? null : _add,
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading subjects…'),
          )
        else if (_error != null)
          ErrorState(error: _error!, onRetry: _load)
        else if (_selected.isEmpty)
          const UiCard(
            child: UiEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No individual subjects added yet',
            ),
          )
        else
          DataTableCard(
            columns: const [
              UiColumn('Subject, teacher and class', flex: 20),
              UiColumn('', width: 48),
            ],
            rows: [
              for (final row in _selected)
                UiTableRow([
                  UiCellText(
                    _assignmentLabel(
                      row['classsubject'] as Map<String, dynamic>? ?? {},
                    ),
                    bold: true,
                  ),
                  IconButton(
                    tooltip: 'Remove subject',
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    onPressed: () async {
                      await _repository.removeStudentSubject(
                        row['studentsubjectid'] as String,
                      );
                      await _load();
                    },
                  ),
                ]),
            ],
          ),
      ],
    );
  }
}
