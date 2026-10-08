import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _progressChildrenProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final uid = ref.watch(authProvider).user!.userId;
  final g = await supabase
      .from('guardian')
      .select('guardianid')
      .eq('userid', uid)
      .single();
  final rows = await supabase
      .from('studentguardian')
      .select('student(studentid, firstname, lastname, enrollmentstatus)')
      .eq('guardianid', g['guardianid'] as String);
  return List<Map<String, dynamic>>.from(rows as List);
});

final _progressYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

/// Loads all grades for a student in a given academic year, with assessment +
/// classsubject + subject + class details.
/// NOTE: PostgREST does not support nested .eq() filters across joins, so we
/// fetch all grades for the student and filter by yearId client-side.
final _studentGradesProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String studentId, String yearId})
    >((ref, args) async {
      // Fetch all grades for this student with full join
      final rows = await supabase
          .from('grade')
          .select('''
        gradeid, score, gradestatus,
        assessment(
          assessmentname, assessmenttype, maxscore,
          classsubject(
            academicyearid,
            subject(subjectname),
            class(classroomname)
          )
        )
      ''')
          .eq('studentid', args.studentId)
          .order('gradeid');

      // Filter client-side by academicyearid — PostgREST ignores nested .eq()
      final all = List<Map<String, dynamic>>.from(rows as List);
      return all.where((r) {
        final a = r['assessment'] as Map<String, dynamic>?;
        final cs = a?['classsubject'] as Map<String, dynamic>?;
        return cs?['academicyearid'] == args.yearId;
      }).toList();
    });

/// Teacher comments for a student in a year.
final _studentCommentsProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String studentId, String yearId})
    >((ref, args) async {
      final rows = await supabase
          .from('teachercomment')
          .select('comment, staff(firstname, lastname)')
          .eq('studentid', args.studentId)
          .eq('academicyearid', args.yearId);
      return List<Map<String, dynamic>>.from(rows as List);
    });

// ── Page ──────────────────────────────────────────────────────────────────────

/// Guardian view of academic progress — grades per subject + teacher comments.
class GuardianAcademicProgressPage extends ConsumerStatefulWidget {
  const GuardianAcademicProgressPage({super.key});

  @override
  ConsumerState<GuardianAcademicProgressPage> createState() =>
      _GuardianAcademicProgressPageState();
}

class _GuardianAcademicProgressPageState
    extends ConsumerState<GuardianAcademicProgressPage> {
  String? _studentId;
  String? _studentName;
  String? _yearId;
  String? _yearLabel;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(_progressChildrenProvider);
    final yearsAsync = ref.watch(_progressYearsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Academic Progress'), actions: const []),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Text(
                'No children linked to your account.\n'
                'Contact the school administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          final onlyStudent = children.length == 1
              ? children.single['student'] as Map<String, dynamic>
              : null;
          if (onlyStudent != null && _studentId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _studentId == null) {
                setState(() {
                  _studentId = onlyStudent['studentid'] as String;
                  _studentName =
                      '${onlyStudent['firstname']} ${onlyStudent['lastname']}';
                });
              }
            });
          }
          return Column(
            children: [
              // ── Selectors ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: onlyStudent != null
                    ? InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Child',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.child_care),
                        ),
                        child: Text(
                          '${onlyStudent['firstname']} ${onlyStudent['lastname']}',
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _studentId,
                        decoration: const InputDecoration(
                          labelText: 'Child',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.child_care),
                        ),
                        hint: const Text('Select child'),
                        items: children.map((c) {
                          final s = c['student'] as Map<String, dynamic>;
                          final id = s['studentid'] as String;
                          final nm = '${s['firstname']} ${s['lastname']}';
                          return DropdownMenuItem(value: id, child: Text(nm));
                        }).toList(),
                        onChanged: (v) {
                          final s = children
                              .map((c) => c['student'] as Map<String, dynamic>)
                              .firstWhere((s) => s['studentid'] == v);
                          setState(() {
                            _studentId = v;
                            _studentName = '${s['firstname']} ${s['lastname']}';
                          });
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: yearsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(friendlyError(e)),
                  data: (years) => DropdownButtonFormField<String>(
                    initialValue: _yearId,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    hint: const Text('Select year'),
                    items: years.map((y) {
                      final id = y['academicyearid'] as String;
                      final lbl = '${y['academicyear']} — ${y['term']}';
                      return DropdownMenuItem(value: id, child: Text(lbl));
                    }).toList(),
                    onChanged: (v) {
                      final y = years.firstWhere(
                        (y) => y['academicyearid'] == v,
                      );
                      setState(() {
                        _yearId = v;
                        _yearLabel = '${y['academicyear']} — ${y['term']}';
                      });
                    },
                  ),
                ),
              ),

              // ── Progress view ────────────────────────────────────────────
              Expanded(
                child: _studentId == null || _yearId == null
                    ? const Center(
                        child: Text(
                          'Select a child and academic year',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : _ProgressView(
                        studentId: _studentId!,
                        studentName: _studentName!,
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Progress view ─────────────────────────────────────────────────────────────

class _ProgressView extends ConsumerWidget {
  final String studentId;
  final String studentName;
  final String yearId;
  final String yearLabel;

  const _ProgressView({
    required this.studentId,
    required this.studentName,
    required this.yearId,
    required this.yearLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesArgs = (studentId: studentId, yearId: yearId);
    final commentsArgs = (studentId: studentId, yearId: yearId);
    final gradesAsync = ref.watch(_studentGradesProvider(gradesArgs));
    final commentsAsync = ref.watch(_studentCommentsProvider(commentsArgs));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Student / year banner ──────────────────────────────────────────
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(yearLabel, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Grades by subject ──────────────────────────────────────────────
        const Text(
          'Grades',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        gradesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading grades: $e'),
          data: (grades) {
            if (grades.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No grades recorded for this period yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            // Group by subject
            final bySubject = <String, List<Map<String, dynamic>>>{};
            for (final g in grades) {
              final a = g['assessment'] as Map<String, dynamic>?;
              final cs = a?['classsubject'] as Map<String, dynamic>?;
              final sub =
                  (cs?['subject'] as Map<String, dynamic>?)?['subjectname']
                      as String? ??
                  'Unknown Subject';
              bySubject.putIfAbsent(sub, () => []).add(g);
            }

            return Column(
              children: bySubject.entries.map((entry) {
                final subject = entry.key;
                final subGrades = entry.value;
                final totalScore = subGrades.fold<double>(
                  0,
                  (sum, g) => sum + ((g['score'] as num?)?.toDouble() ?? 0),
                );
                final totalMax = subGrades.fold<double>(0, (sum, g) {
                  final a = g['assessment'] as Map<String, dynamic>?;
                  return sum + ((a?['maxscore'] as num?)?.toDouble() ?? 0);
                });
                final pct = totalMax > 0
                    ? (totalScore / totalMax * 100).toStringAsFixed(1)
                    : '—';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _gradeColor(
                        totalMax > 0 ? totalScore / totalMax : 0,
                      ),
                      child: Text(
                        '$pct%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      subject,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$totalScore / $totalMax — $pct%'),
                    children: subGrades.map((g) {
                      final a = g['assessment'] as Map<String, dynamic>?;
                      final name = a?['assessmentname'] as String? ?? '—';
                      final type = a?['assessmenttype'] as String? ?? '';
                      final max = a?['maxscore'];
                      final score = g['score'];
                      final status = g['gradestatus'] as String;
                      return ListTile(
                        dense: true,
                        title: Text(name),
                        subtitle: Text('$type  •  Max: $max'),
                        trailing: _ScoreBadge(
                          score: score,
                          max: max,
                          status: status,
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Teacher comments ───────────────────────────────────────────────
        const Text(
          'Teacher Comments',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        commentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading comments: $e'),
          data: (comments) {
            if (comments.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No teacher comments for this period.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            return Column(
              children: comments.map((c) {
                final staff = c['staff'] as Map<String, dynamic>?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (staff != null)
                          Text(
                            '${staff['firstname']} ${staff['lastname']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(c['comment'] as String),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Color _gradeColor(double ratio) {
    if (ratio >= 0.75) return Colors.green;
    if (ratio >= 0.50) return Colors.orange;
    return Colors.red;
  }
}

// ── Score badge ───────────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  final dynamic score;
  final dynamic max;
  final String status;

  const _ScoreBadge({
    required this.score,
    required this.max,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'ABSENT') {
      return const Chip(
        label: Text('Absent'),
        backgroundColor: Colors.red,
        labelStyle: TextStyle(color: Colors.white, fontSize: 11),
        padding: EdgeInsets.zero,
      );
    }
    if (score == null) {
      return Chip(
        label: Text(status),
        backgroundColor: Colors.grey.shade200,
        padding: EdgeInsets.zero,
        labelStyle: const TextStyle(fontSize: 11),
      );
    }
    final s = (score as num).toDouble();
    final m = (max as num).toDouble();
    final ratio = m > 0 ? s / m : 0.0;
    final color = ratio >= 0.75
        ? Colors.green
        : ratio >= 0.50
        ? Colors.orange
        : Colors.red;
    return Chip(
      label: Text('$s / $m'),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      padding: EdgeInsets.zero,
    );
  }
}
