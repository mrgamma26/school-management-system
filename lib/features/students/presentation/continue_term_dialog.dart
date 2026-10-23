import 'package:flutter/material.dart';

import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';

const _termOrder = ['TERM_1', 'TERM_2', 'TERM_3'];

String _termText(String term) =>
    term.replaceAll('_', ' ').replaceFirst('TERM', 'Term');

/// Moves every student of a class from the previous term into [target] term
/// of the same school year: one class placement and the term's subject
/// enrolments per student (database function `continue_student_to_term`).
/// Returns a summary message, or null when the dialog was cancelled.
Future<String?> showContinueToNextTermDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _ContinueTermDialog(),
  );
}

class _ContinueTermDialog extends StatefulWidget {
  const _ContinueTermDialog();

  @override
  State<_ContinueTermDialog> createState() => _ContinueTermDialogState();
}

class _ContinueTermDialogState extends State<_ContinueTermDialog> {
  List<Map<String, dynamic>> _classes = const [];
  List<Map<String, dynamic>> _periods = const [];
  String? _classId;
  String? _targetId;
  bool _loading = true;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final classes = await supabase
          .from('class')
          .select('classid, classroomname, form')
          .order('classroomname');
      final periods = await supabase
          .from('academicyear')
          .select('academicyearid, academicyear, term, form')
          .order('academicyear', ascending: false);
      if (!mounted) return;
      setState(() {
        _classes = List<Map<String, dynamic>>.from(classes as List);
        _periods = List<Map<String, dynamic>>.from(periods as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _class =>
      _classes.where((c) => c['classid'] == _classId).firstOrNull;

  /// Term 2 and Term 3 periods of the selected class's form.
  List<Map<String, dynamic>> get _targets {
    final form = _class?['form'];
    if (form == null) return const [];
    final list = _periods.where((p) => p['form'] == form).toList();
    list.sort((a, b) {
      final y = (b['academicyear'] as int).compareTo(a['academicyear'] as int);
      if (y != 0) return y;
      return _termOrder
          .indexOf(a['term'] as String)
          .compareTo(_termOrder.indexOf(b['term'] as String));
    });
    return list;
  }

  /// Term 1 is reached from Term 3 of the year before, through the Head
  /// Teacher's progression review, so its entry reads that way.
  String _periodLabel(Map<String, dynamic> p) {
    final year = p['academicyear'] as int;
    if (p['term'] == 'TERM_1') {
      return '$year/${year + 1} Term 1 (from Term 3 via Head Teacher progression)';
    }
    return '$year/${year + 1} ${_termText(p['term'] as String)}';
  }

  Future<void> _requestProgression(Map<String, dynamic> target) async {
    final year = (target['academicyear'] as int) - 1;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final result = await supabase.rpc(
        'request_progression_reviews',
        params: {'p_class_id': _classId, 'p_school_year': year},
      );
      if (!mounted) return;
      final r = Map<String, dynamic>.from(result as Map);
      Navigator.pop(
        context,
        '${r['className']}: ${r['recorded']} of ${r['students']} students sent '
        'to the Head Teacher for progression ($year/${year + 1}). Promoted '
        'students are placed in the next form for Term 1.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  Future<void> _run() async {
    final target = _periods.firstWhere((p) => p['academicyearid'] == _targetId);
    if (target['term'] == 'TERM_1') return _requestProgression(target);
    final previousTerm =
        _termOrder[_termOrder.indexOf(target['term'] as String) - 1];
    final source = _periods.where(
      (p) =>
          p['academicyear'] == target['academicyear'] &&
          p['form'] == target['form'] &&
          p['term'] == previousTerm,
    );
    if (source.isEmpty) {
      setState(() => _error = 'The previous term is not set up for this form.');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final rows = await supabase
          .from('studentclasshistory')
          .select('studentid')
          .eq('classid', _classId!)
          .eq('academicyearid', source.first['academicyearid'] as String);
      final students = {
        for (final r in rows as List) (r as Map)['studentid'] as String,
      };
      if (students.isEmpty) {
        setState(() {
          _running = false;
          _error =
              'No students are placed in ${_class!['classroomname']} for '
              '${_termText(previousTerm)}.';
        });
        return;
      }
      var done = 0;
      String? firstError;
      for (final id in students) {
        try {
          await supabase.rpc(
            'continue_student_to_term',
            params: {
              'p_student_id': id,
              'p_class_id': _classId,
              'p_academic_year_id': _targetId,
            },
          );
          done++;
        } catch (e) {
          firstError ??= friendlyError(e);
        }
      }
      if (!mounted) return;
      final summary =
          '$done of ${students.length} students of '
          '${_class!['classroomname']} continued to ${_periodLabel(target)}.'
          '${firstError == null ? '' : ' Not continued: $firstError'}';
      Navigator.pop(context, summary);
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets;
    return AlertDialog(
      title: const Text('Continue to next term'),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Term 2 or Term 3: every student placed in the class for '
                    'the previous term is placed in the same class for the '
                    'chosen term and enrolled in its subjects.\n'
                    'Term 1 of the next year: the class has finished Term 3, '
                    'so each student is sent to the Head Teacher for a '
                    'progression review. A promoted student moves to the next '
                    'form (Form 4 students complete school).',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _classId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: [
                      for (final c in _classes)
                        DropdownMenuItem(
                          value: c['classid'] as String,
                          child: Text(c['classroomname'] as String),
                        ),
                    ],
                    onChanged: _running
                        ? null
                        : (v) => setState(() {
                            _classId = v;
                            _targetId = null;
                            _error = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('target-$_classId'),
                    initialValue: _targetId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Continue to term',
                    ),
                    items: [
                      for (final p in targets)
                        DropdownMenuItem(
                          value: p['academicyearid'] as String,
                          child: Text(_periodLabel(p)),
                        ),
                    ],
                    onChanged: _running
                        ? null
                        : (v) => setState(() {
                            _targetId = v;
                            _error = null;
                          }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _running || _classId == null || _targetId == null
              ? null
              : _run,
          icon: _running
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.east_rounded),
          label: const Text('Continue students'),
        ),
      ],
    );
  }
}
