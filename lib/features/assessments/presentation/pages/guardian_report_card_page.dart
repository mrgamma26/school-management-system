import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/services/export_service.dart';
import '../../../../widgets/ui_kit.dart';
import '../widgets/guardian_report_gate.dart';

// ── FIX 10: Report Card View for Guardians ────────────────────────────────────
// Displays academic performance aggregated across all three terms for each
// student linked to the guardian. Shows term-by-term breakdown per subject.

// ── Providers ─────────────────────────────────────────────────────────────────

final _reportCardChildrenProvider = FutureProvider<List<Map<String, dynamic>>>((
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

/// Loads all grades for a student across all terms in a given academic year.
/// Groups by subject and term for report card display.
final _reportCardDataProvider =
    FutureProvider.family<Map<int, Map<String, dynamic>>, String>((
      ref,
      studentId,
    ) async {
      // Fetch all grades for this student with full details
      final rows = await supabase
          .from('grade')
          .select('''
    gradeid, score, gradestatus,
    assessment(
      assessmentname, assessmenttype, maxscore,
      classsubject(
        academicyearid,
        subject(subjectid, subjectname),
        academicyear(academicyear, term)
      )
    )
  ''')
          .eq('studentid', studentId)
          .order('gradeid');

      final grades = List<Map<String, dynamic>>.from(rows as List);

      // Group by academic year
      final byYear = <int, Map<String, dynamic>>{};

      for (final g in grades) {
        final assessment = g['assessment'] as Map<String, dynamic>?;
        if (assessment == null) continue;

        final cs = assessment['classsubject'] as Map<String, dynamic>?;
        if (cs == null) continue;

        final ay = cs['academicyear'] as Map<String, dynamic>?;
        if (ay == null) continue;

        final year = ay['academicyear'] as int;
        // The database stores TERM_1 / TERM_2 / TERM_3; this page orders and labels by TERM1 / TERM2 / TERM3.
        final term = (ay['term'] as String).replaceAll('_', '');
        final subject = cs['subject'] as Map<String, dynamic>?;
        final subjectName = subject?['subjectname'] as String? ?? 'Unknown';

        if (!byYear.containsKey(year)) {
          byYear[year] = {'year': year, 'terms': <String, dynamic>{}};
        }

        final yearData = byYear[year]!;
        final terms = yearData['terms'] as Map<String, dynamic>;

        if (!terms.containsKey(term)) {
          terms[term] = <String, List<Map<String, dynamic>>>{};
        }

        final termData = terms[term] as Map<String, List<Map<String, dynamic>>>;
        termData.putIfAbsent(subjectName, () => []).add(g);
      }

      return byYear;
    });

// ── Page ──────────────────────────────────────────────────────────────────────

/// Guardian Report Card View - shows all three terms for each academic year.
class GuardianReportCardPage extends ConsumerStatefulWidget {
  const GuardianReportCardPage({super.key});

  @override
  ConsumerState<GuardianReportCardPage> createState() =>
      _GuardianReportCardPageState();
}

class _GuardianReportCardPageState
    extends ConsumerState<GuardianReportCardPage> {
  String? _studentId;
  String? _studentName;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(_reportCardChildrenProvider);

    return PageFrame(
      kicker: 'Guardian · Results',
      title: 'Student Report Card',
      subtitle:
          'School-branded report with teacher comments. Withheld while a balance is outstanding.',
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
              // ── Child selector ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
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
                          labelText: 'Select Child',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.child_care),
                        ),
                        hint: const Text('Choose a child'),
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

              // ── Report card view ─────────────────────────────────────────
              Expanded(
                child: _studentId == null
                    ? const Center(
                        child: Text(
                          'Select a child to view their report card',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : GuardianReportGate(
                        studentId: _studentId!,
                        child: GuardianReportCardView(
                          studentId: _studentId!,
                          studentName: _studentName!,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Report card view ──────────────────────────────────────────────────────────

class GuardianReportCardView extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const GuardianReportCardView({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  /// Generate PDF-exportable rows from report card data
  List<List<String>> _generatePdfRows(Map<int, Map<String, dynamic>> byYear) {
    final rows = <List<String>>[];

    // Sort years descending (most recent first)
    final sortedYears = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final year in sortedYears) {
      final yearData = byYear[year]!;
      final terms = yearData['terms'] as Map<String, dynamic>;
      final termOrder = ['TERM1', 'TERM2', 'TERM3'];
      final orderedTerms = termOrder
          .where((t) => terms.containsKey(t))
          .map((t) => MapEntry(t, terms[t]))
          .toList();

      for (final entry in orderedTerms) {
        final termName = _formatTermName(entry.key);
        final subjects = entry.value as Map<String, List<Map<String, dynamic>>>;

        for (final subjectEntry in subjects.entries) {
          final subjectName = subjectEntry.key;
          final grades = subjectEntry.value;

          final totalScore = grades.fold<double>(
            0,
            (sum, g) => sum + ((g['score'] as num?)?.toDouble() ?? 0),
          );
          final totalMax = grades.fold<double>(0, (sum, g) {
            final a = g['assessment'] as Map<String, dynamic>?;
            return sum + ((a?['maxscore'] as num?)?.toDouble() ?? 0);
          });
          final percentage = totalMax > 0
              ? (totalScore / totalMax * 100).toStringAsFixed(1)
              : '0.0';
          final grade = _computeGrade(totalMax > 0 ? totalScore / totalMax : 0);

          rows.add([
            'Year $year',
            termName,
            subjectName,
            grade,
            '$percentage%',
            '${totalScore.toStringAsFixed(1)} / ${totalMax.toStringAsFixed(1)}',
          ]);
        }
      }
    }

    return rows;
  }

  String _formatTermName(String term) {
    switch (term) {
      case 'TERM1':
        return 'Term 1';
      case 'TERM2':
        return 'Term 2';
      case 'TERM3':
        return 'Term 3';
      default:
        return term;
    }
  }

  String _computeGrade(double ratio) {
    if (ratio >= 0.80) return 'A';
    if (ratio >= 0.70) return 'B';
    if (ratio >= 0.60) return 'C';
    if (ratio >= 0.50) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_reportCardDataProvider(studentId));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading report card: $e')),
      data: (byYear) {
        if (byYear.isEmpty) {
          return const Center(
            child: Text(
              'No grades recorded for this student yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: [
            // Download PDF button in a card
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final rows = _generatePdfRows(byYear);
                    await ExportService.exportToPdf(
                      title: 'Report Card',
                      subtitle: studentName,
                      headers: [
                        'Year',
                        'Term',
                        'Subject',
                        'Grade',
                        'Percentage',
                        'Score',
                      ],
                      rows: rows,
                      footer:
                          'Generated on ${DateTime.now().toIso8601String().substring(0, 10)}',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error generating PDF: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Expanded report card view
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // ── Student banner ────────────────────────────────────────────
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: const Icon(
                              Icons.school,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const Text(
                                  'Full Academic Report Card',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.verified, color: Colors.teal),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Year cards ─────────────────────────────────────────────────
                  ..._generateYearCards(byYear),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _generateYearCards(Map<int, Map<String, dynamic>> byYear) {
    final sortedYears = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedYears.map((year) {
      final yearData = byYear[year]!;
      final terms = yearData['terms'] as Map<String, dynamic>;
      return _YearCard(year: year, terms: terms);
    }).toList();
  }
}

// ── Year card ─────────────────────────────────────────────────────────────────

class _YearCard extends StatelessWidget {
  final int year;
  final Map<String, dynamic> terms;

  const _YearCard({required this.year, required this.terms});

  @override
  Widget build(BuildContext context) {
    // Ensure term order: Term 1, Term 2, Term 3
    final termOrder = ['TERM1', 'TERM2', 'TERM3'];
    final orderedTerms = termOrder
        .where((t) => terms.containsKey(t))
        .map((t) => MapEntry(t, terms[t]))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Year header
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Academic Year $year',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Term sections
            if (orderedTerms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No grades recorded for this year.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...orderedTerms.map((entry) {
                final termName = formatTermName(entry.key);
                final subjects =
                    entry.value as Map<String, List<Map<String, dynamic>>>;
                return _TermSection(termName: termName, subjects: subjects);
              }),
          ],
        ),
      ),
    );
  }

  String formatTermName(String term) {
    switch (term) {
      case 'TERM1':
        return 'Term 1';
      case 'TERM2':
        return 'Term 2';
      case 'TERM3':
        return 'Term 3';
      default:
        return term;
    }
  }
}

// ── Term section ──────────────────────────────────────────────────────────────

class _TermSection extends StatelessWidget {
  final String termName;
  final Map<String, List<Map<String, dynamic>>> subjects;

  const _TermSection({required this.termName, required this.subjects});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Term header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            termName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),

        // Subject rows
        ...subjects.entries.map((entry) {
          final subjectName = entry.key;
          final grades = entry.value;

          // Calculate totals
          final totalScore = grades.fold<double>(
            0,
            (sum, g) => sum + ((g['score'] as num?)?.toDouble() ?? 0),
          );
          final totalMax = grades.fold<double>(0, (sum, g) {
            final a = g['assessment'] as Map<String, dynamic>?;
            return sum + ((a?['maxscore'] as num?)?.toDouble() ?? 0);
          });
          final percentage = totalMax > 0
              ? (totalScore / totalMax * 100).toStringAsFixed(1)
              : '0.0';
          final grade = computeGrade(totalMax > 0 ? totalScore / totalMax : 0);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.grey.shade50,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: gradeColor(grade),
                child: Text(
                  grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              title: Text(
                subjectName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${grades.length} assessment(s)'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: gradeColor(grade),
                    ),
                  ),
                  Text(
                    '${totalScore.toStringAsFixed(1)} / ${totalMax.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }

  String computeGrade(double ratio) {
    if (ratio >= 0.80) return 'A';
    if (ratio >= 0.70) return 'B';
    if (ratio >= 0.60) return 'C';
    if (ratio >= 0.50) return 'D';
    return 'F';
  }

  Color gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.lightGreen;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.deepOrange;
      case 'F':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
