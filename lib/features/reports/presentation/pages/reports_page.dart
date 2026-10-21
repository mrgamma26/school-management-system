import 'package:school_management_app/features/academics/domain/models/academic_year.dart';
import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/services/export_service.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../report_providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _reportYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Daily financial breakdown ─────────────────────────────────────────────────

final _dailyFinancialProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      yearId,
    ) async {
      final payments = await supabase
          .from('payment')
          .select('amount, paymentdate, feestructure!inner(academicyearid)')
          .eq('feestructure.academicyearid', yearId)
          .order('paymentdate', ascending: false);

      // Group by date
      final grouped = <String, double>{};
      for (final p in payments as List) {
        final date = p['paymentdate'] as String;
        final amount = (p['amount'] as num).toDouble();
        grouped[date] = (grouped[date] ?? 0.0) + amount;
      }

      // Convert to list and sort by date descending
      final result =
          grouped.entries
              .map((e) => {'date': e.key, 'amount': e.value})
              .toList()
            ..sort(
              (a, b) => (b['date'] as String).compareTo(a['date'] as String),
            );

      return result;
    });

// ── Monthly financial breakdown ───────────────────────────────────────────────

final _monthlyFinancialProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      yearId,
    ) async {
      final payments = await supabase
          .from('payment')
          .select('amount, paymentdate, feestructure!inner(academicyearid)')
          .eq('feestructure.academicyearid', yearId)
          .order('paymentdate', ascending: false);

      // Group by year-month
      final grouped = <String, double>{};
      for (final p in payments as List) {
        final date = p['paymentdate'] as String;
        final yearMonth = date.substring(0, 7); // Extract YYYY-MM
        final amount = (p['amount'] as num).toDouble();
        grouped[yearMonth] = (grouped[yearMonth] ?? 0.0) + amount;
      }

      // Convert to list and sort by month descending
      final result =
          grouped.entries
              .map((e) => {'month': e.key, 'amount': e.value})
              .toList()
            ..sort(
              (a, b) => (b['month'] as String).compareTo(a['month'] as String),
            );

      return result;
    });

// ── Financial summary ─────────────────────────────────────────────────────────

final _financialReportProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, yearId) async {
      // Total collected
      final payments = await supabase
          .from('payment')
          .select('amount, feestructure!inner(academicyearid)')
          .eq('feestructure.academicyearid', yearId);
      final totalCollected = (payments as List).fold<double>(
        0.0,
        (s, r) => s + (r['amount'] as num).toDouble(),
      );

      // Total expected (sum of fee structures for the year)
      final fees = await supabase
          .from('feestructure')
          .select('amount')
          .eq('academicyearid', yearId);
      final totalExpected = (fees as List).fold<double>(
        0.0,
        (s, r) => s + (r['amount'] as num).toDouble(),
      );

      // Count payments
      final paymentCount = (payments as List).length;

      // Total adjustments
      final adjustments = await supabase
          .from('financialadjustment')
          .select('amount');
      final totalAdj = (adjustments as List).fold<double>(
        0.0,
        (s, r) => s + (r['amount'] as num).toDouble(),
      );

      return {
        'total_collected': totalCollected,
        'total_expected': totalExpected,
        'payment_count': paymentCount,
        'total_adjustments': totalAdj,
        'collection_rate': totalExpected > 0
            ? (totalCollected / totalExpected * 100).toStringAsFixed(1)
            : '—',
      };
    });

// ── Enrolment summary ─────────────────────────────────────────────────────────

// ── Performance summary ───────────────────────────────────────────────────────

final _performanceReportProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, yearId) async {
      // Average score per subject
      final rows = await supabase
          .from('grade')
          .select('''
        score,
        assessment(
          maxscore,
          classsubject(
            academicyearid,
            subject(subjectname)
          )
        )
      ''')
          .not('score', 'is', null)
          .eq('assessment.classsubject.academicyearid', yearId);

      final subjectData = <String, List<double>>{};
      for (final r in rows as List) {
        final a = r['assessment'] as Map<String, dynamic>?;
        final cs = a?['classsubject'] as Map<String, dynamic>?;
        final subMap = cs?['subject'] as Map<String, dynamic>?;
        final sub = subMap?['subjectname'] as String? ?? 'Unknown';
        final score = (r['score'] as num).toDouble();
        final max = (a?['maxscore'] as num?)?.toDouble() ?? 100;
        final pct = max > 0 ? score / max * 100 : 0.0;
        subjectData.putIfAbsent(sub, () => []).add(pct);
      }

      final avgBySubject = subjectData.map(
        (k, v) => MapEntry(
          k,
          (v.reduce((a, b) => a + b) / v.length).toStringAsFixed(1),
        ),
      );

      // Progression outcomes
      final prog = await supabase
          .from('progressionreview')
          .select('decision')
          .eq('academicyearid', yearId);

      final progCounts = <String, int>{};
      for (final r in prog as List) {
        final d = r['decision'] as String;
        progCounts[d] = (progCounts[d] ?? 0) + 1;
      }

      return {
        'avg_by_subject': avgBySubject,
        'progression_counts': progCounts,
        'grade_count': (rows as List).length,
      };
    });

// ── Page ──────────────────────────────────────────────────────────────────────

/// Reports hub — financial summary, enrolment breakdown, performance overview.
/// Accessible to: Head Teacher, Administrator, Super User, System Admin.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  int _tab = 0;
  String? _yearId;
  String? _yearLabel;

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_reportYearsProvider);
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.mobile;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          phone ? 16 : 24,
          phone ? 16 : 24,
          phone ? 16 : 24,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHead(
              kicker: 'Reports',
              title: 'Reports',
              subtitle:
                  'Collection, enrolment and performance summaries for an academic year.',
            ),
            // ── Year selector ──────────────────────────────────────────────
            yearsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => UiNotice('Error loading years: $e'),
              data: (years) => UiCard(
                padding: const EdgeInsets.all(12),
                child: UiField(
                  label: 'Academic year',
                  child: DropdownButtonFormField<String>(
                    initialValue: _yearId,
                    hint: const Text('Select academic year'),
                    items: years.map((y) {
                      final id = y['academicyearid'] as String;
                      final lbl = formatAcademicYear(y['academicyear']);
                      return DropdownMenuItem(value: id, child: Text(lbl));
                    }).toList(),
                    onChanged: (v) {
                      final y = years.firstWhere(
                        (y) => y['academicyearid'] == v,
                      );
                      setState(() {
                        _yearId = v;
                        _yearLabel = formatAcademicYear(y['academicyear']);
                      });
                    },
                  ),
                ),
              ),
            ),
            TabsBar(
              tabs: const ['Finance', 'Breakdown', 'Enrolment', 'Performance'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),

            // ── Tab views ──────────────────────────────────────────────────
            Expanded(
              child: _yearId == null
                  ? const SingleChildScrollView(
                      child: UiCard(
                        child: UiEmptyState(
                          icon: Icons.analytics_outlined,
                          title: 'Select an academic year',
                          message:
                              'Select an academic year to generate reports.',
                        ),
                      ),
                    )
                  : switch (_tab) {
                      0 => _FinancialReport(
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
                      1 => _FinancialBreakdown(
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
                      2 => _EnrolmentReport(
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
                      _ => _PerformanceReport(
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Financial report tab ──────────────────────────────────────────────────────

class _FinancialReport extends ConsumerWidget {
  final String yearId;
  final String yearLabel;
  const _FinancialReport({required this.yearId, required this.yearLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_financialReportProvider(yearId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (data) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportHeader(
            'Financial Summary',
            yearLabel,
            Icons.payments,
            Colors.green,
          ),
          const SizedBox(height: 8),
          // Export button
          ElevatedButton.icon(
            onPressed: () async {
              await ExportService.exportFinancialReportPdf(
                yearLabel: yearLabel,
                totalCollected: data['total_collected'] as double,
                totalExpected: data['total_expected'] as double,
                paymentCount: data['payment_count'] as int,
                totalAdjustments: data['total_adjustments'] as double,
                collectionRate: data['collection_rate'] as String,
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export to PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _StatCard(
            'Total Collected',
            'MWK ${(data['total_collected'] as double).toStringAsFixed(2)}',
            Icons.payments,
            Colors.green,
          ),
          const SizedBox(height: 8),
          _StatCard(
            'Total Expected',
            'MWK ${(data['total_expected'] as double).toStringAsFixed(2)}',
            Icons.account_balance,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _StatCard(
            'Collection Rate',
            '${data['collection_rate']}%',
            Icons.percent,
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _StatCard(
            'Number of Payments',
            '${data['payment_count']}',
            Icons.receipt_long,
            AppColors.primary,
          ),
          const SizedBox(height: 8),
          _StatCard(
            'Total Adjustments',
            'MWK ${(data['total_adjustments'] as double).toStringAsFixed(2)}',
            Icons.tune,
            Colors.red,
          ),
        ],
      ),
    );
  }
}

// ── Financial breakdown tab ───────────────────────────────────────────────────

class _FinancialBreakdown extends ConsumerStatefulWidget {
  final String yearId;
  final String yearLabel;
  const _FinancialBreakdown({required this.yearId, required this.yearLabel});

  @override
  ConsumerState<_FinancialBreakdown> createState() =>
      _FinancialBreakdownState();
}

class _FinancialBreakdownState extends ConsumerState<_FinancialBreakdown> {
  String _viewMode = 'daily'; // 'daily' or 'monthly'

  @override
  Widget build(BuildContext context) {
    final asyncDaily = ref.watch(_dailyFinancialProvider(widget.yearId));
    final asyncMonthly = ref.watch(_monthlyFinancialProvider(widget.yearId));

    return Column(
      children: [
        // Toggle between daily and monthly
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'daily',
                      label: Text('Daily'),
                      icon: Icon(Icons.calendar_today),
                    ),
                    ButtonSegment(
                      value: 'monthly',
                      label: Text('Monthly'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (Set<String> selected) {
                    setState(() {
                      _viewMode = selected.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _viewMode == 'daily'
              ? asyncDaily.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (data) => _DailyBreakdownList(
                    data: data,
                    yearLabel: widget.yearLabel,
                  ),
                )
              : asyncMonthly.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (data) => _MonthlyBreakdownList(
                    data: data,
                    yearLabel: widget.yearLabel,
                  ),
                ),
        ),
      ],
    );
  }
}

// Daily breakdown list
class _DailyBreakdownList extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String yearLabel;

  const _DailyBreakdownList({required this.data, required this.yearLabel});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No payments recorded for this academic year',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final total = data.fold<double>(
      0.0,
      (sum, item) => sum + (item['amount'] as double),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ReportHeader(
          'Daily Financial Breakdown',
          yearLabel,
          Icons.calendar_view_day,
          Colors.teal,
        ),
        const SizedBox(height: 16),
        _StatCard(
          'Total Collections',
          'MWK ${total.toStringAsFixed(2)}',
          Icons.payments,
          Colors.teal,
        ),
        const SizedBox(height: 8),
        _StatCard(
          'Number of Days',
          '${data.length}',
          Icons.calendar_today,
          Colors.blue,
        ),
        const SizedBox(height: 8),
        _StatCard(
          'Average per Day',
          'MWK ${(total / data.length).toStringAsFixed(2)}',
          Icons.show_chart,
          AppColors.primary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Daily Collections',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...data.map((item) {
          final date = item['date'] as String;
          final amount = item['amount'] as double;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withValues(alpha: 0.15),
                radius: 18,
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.teal,
                  size: 16,
                ),
              ),
              title: Text(
                _formatDate(date),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                date,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: Text(
                'MWK ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.teal,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

// Monthly breakdown list
class _MonthlyBreakdownList extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String yearLabel;

  const _MonthlyBreakdownList({required this.data, required this.yearLabel});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No payments recorded for this academic year',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final total = data.fold<double>(
      0.0,
      (sum, item) => sum + (item['amount'] as double),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ReportHeader(
          'Monthly Financial Breakdown',
          yearLabel,
          Icons.calendar_month,
          Colors.deepPurple,
        ),
        const SizedBox(height: 16),
        _StatCard(
          'Total Collections',
          'MWK ${total.toStringAsFixed(2)}',
          Icons.payments,
          Colors.deepPurple,
        ),
        const SizedBox(height: 8),
        _StatCard(
          'Number of Months',
          '${data.length}',
          Icons.calendar_today,
          Colors.blue,
        ),
        const SizedBox(height: 8),
        _StatCard(
          'Average per Month',
          'MWK ${(total / data.length).toStringAsFixed(2)}',
          Icons.show_chart,
          Colors.orange,
        ),
        const SizedBox(height: 16),
        const Text(
          'Monthly Collections',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...data.map((item) {
          final month = item['month'] as String;
          final amount = item['amount'] as double;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                radius: 18,
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.deepPurple,
                  size: 16,
                ),
              ),
              title: Text(
                _formatMonth(month),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                month,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: Text(
                'MWK ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatMonth(String yearMonth) {
    try {
      final parts = yearMonth.split('-');
      if (parts.length != 2) return yearMonth;
      final year = parts[0];
      final monthNum = int.parse(parts[1]);
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[monthNum - 1]} $year';
    } catch (_) {
      return yearMonth;
    }
  }
}

// ── Enrolment report tab ──────────────────────────────────────────────────────

class _EnrolmentReport extends ConsumerWidget {
  final String yearId;
  final String yearLabel;
  const _EnrolmentReport({required this.yearId, required this.yearLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(enrolmentReportProvider(yearId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(friendlyError(e), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(enrolmentReportProvider(yearId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        final byClass = data.byClass;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReportHeader(
              'Enrolment Summary',
              yearLabel,
              Icons.school,
              AppColors.primary,
            ),
            const SizedBox(height: 8),
            // Export button
            ElevatedButton.icon(
              onPressed: () async {
                await ExportService.exportEnrolmentReportPdf(
                  yearLabel: yearLabel,
                  totalEnrolled: data.totalEnrolled,
                  maleCount: data.maleCount,
                  femaleCount: data.femaleCount,
                  activeInYear: data.activeInYear,
                  byClass: byClass,
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export to PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _StatCard(
              'Total Enrolled',
              '${data.totalEnrolled}',
              Icons.groups,
              AppColors.primary,
            ),
            const SizedBox(height: 8),
            _StatCard(
              'Male Students',
              '${data.maleCount}',
              Icons.male,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _StatCard(
              'Female Students',
              '${data.femaleCount}',
              Icons.female,
              Colors.pink,
            ),
            const SizedBox(height: 8),
            _StatCard(
              'Active in Selected Year',
              '${data.activeInYear}',
              Icons.calendar_today,
              Colors.teal,
            ),
            const SizedBox(height: 16),
            const Text(
              'Students by Class',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...byClass.entries.map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 16,
                    child: Icon(Icons.class_, color: Colors.white, size: 14),
                  ),
                  title: Text(e.key),
                  trailing: Chip(
                    label: Text('${e.value}'),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Performance report tab ────────────────────────────────────────────────────

class _PerformanceReport extends ConsumerWidget {
  final String yearId;
  final String yearLabel;
  const _PerformanceReport({required this.yearId, required this.yearLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_performanceReportProvider(yearId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (data) {
        final avgBySubject = data['avg_by_subject'] as Map<String, String>;
        final progCounts = data['progression_counts'] as Map<String, int>;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReportHeader(
              'Performance Summary',
              yearLabel,
              Icons.trending_up,
              Colors.orange,
            ),
            const SizedBox(height: 8),
            // Export button
            ElevatedButton.icon(
              onPressed: () async {
                await ExportService.exportPerformanceReportPdf(
                  yearLabel: yearLabel,
                  gradeCount: data['grade_count'] as int,
                  avgBySubject: avgBySubject,
                  progressionCounts: progCounts,
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export to PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _StatCard(
              'Total Grades Recorded',
              '${data['grade_count']}',
              Icons.grading,
              Colors.orange,
            ),
            const SizedBox(height: 16),

            // Average by subject
            const Text(
              'Average Score by Subject',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (avgBySubject.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No grades recorded yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...avgBySubject.entries.map((e) {
                final pct = double.tryParse(e.value) ?? 0;
                final color = pct >= 75
                    ? Colors.green
                    : pct >= 50
                    ? Colors.orange
                    : Colors.red;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${e.value}%',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),

            // Progression outcomes
            const Text(
              'Progression Outcomes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (progCounts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No progression reviews yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...progCounts.entries.map(
                (e) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: _progColor(e.key),
                      radius: 16,
                      child: Icon(
                        _progIcon(e.key),
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    title: Text(e.key),
                    trailing: Chip(
                      label: Text('${e.value}'),
                      backgroundColor: _progColor(e.key).withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _progColor(String d) => switch (d) {
    'APPROVED' => Colors.green,
    'RETAINED' => Colors.orange,
    'REJECTED' => Colors.red,
    _ => Colors.grey,
  };

  IconData _progIcon(String d) => switch (d) {
    'APPROVED' => Icons.check_circle,
    'RETAINED' => Icons.pause_circle,
    'REJECTED' => Icons.cancel,
    _ => Icons.hourglass_empty,
  };
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ReportHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ReportHeader(this.title, this.subtitle, this.icon, this.color);

  // [color] is kept for the existing call sites; the redesign uses the shared
  // school blue so green / amber / red stay reserved for status.
  @override
  Widget build(BuildContext context) => UiCard(
    color: AppColors.primarySurface,
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  // [color] is kept for the existing call sites; see _ReportHeader.
  @override
  Widget build(BuildContext context) => UiCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.blue800, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}
