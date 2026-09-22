import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/services/export_service.dart';

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

final _enrolmentReportProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, yearId) async {
      // Students per class for the given year
      final rows = await supabase
          .from('studentclasshistory')
          .select('classid, class(classname)')
          .eq('academicyearid', yearId)
          .isFilter('enddate', null);

      final byClass = <String, int>{};
      for (final r in rows as List) {
        final cls = r['class'] as Map<String, dynamic>?;
        final name =
            cls?['classname'] as String? ??
            cls?['classroomname']
                as String? // handle both column name variants
                ??
            'Unknown';
        byClass[name] =
            (byClass[name] ?? 0) + 1; // ← was missing: never populated
      }

      // Total enrolled students
      final total = await supabase
          .from('student')
          .select('studentid')
          .eq('enrollmentstatus', 'enrolled');

      // Gender split
      final male = await supabase
          .from('student')
          .select('studentid')
          .eq('enrollmentstatus', 'enrolled')
          .eq('gender', 'MALE');
      final female = await supabase
          .from('student')
          .select('studentid')
          .eq('enrollmentstatus', 'enrolled')
          .eq('gender', 'FEMALE');

      return {
        'total_enrolled': (total as List).length,
        'male_count': (male as List).length,
        'female_count': (female as List).length,
        'by_class': byClass,
        'active_in_year': (rows as List).length,
      };
    });

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

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _yearId;
  String? _yearLabel;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_reportYearsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.payments), text: 'Finance'),
            Tab(icon: Icon(Icons.calendar_view_day), text: 'Breakdown'),
            Tab(icon: Icon(Icons.school), text: 'Enrolment'),
            Tab(icon: Icon(Icons.trending_up), text: 'Performance'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Year selector ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: yearsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading years: $e'),
              data: (years) => DropdownButtonFormField<String>(
                value: _yearId,
                decoration: const InputDecoration(
                  labelText: 'Academic Year',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                hint: const Text('Select academic year'),
                items: years.map((y) {
                  final id = y['academicyearid'] as String;
                  final lbl = '${y['academicyear']} — ${y['term']}';
                  return DropdownMenuItem(value: id, child: Text(lbl));
                }).toList(),
                onChanged: (v) {
                  final y = years.firstWhere((y) => y['academicyearid'] == v);
                  setState(() {
                    _yearId = v;
                    _yearLabel = '${y['academicyear']} — ${y['term']}';
                  });
                },
              ),
            ),
          ),

          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: _yearId == null
                ? const Center(
                    child: Text(
                      'Select an academic year to generate reports',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _FinancialReport(
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
                      _FinancialBreakdown(
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
                      _EnrolmentReport(
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
                      _PerformanceReport(
                        yearId: _yearId!,
                        yearLabel: _yearLabel!,
                      ),
                    ],
                  ),
          ),
        ],
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
      error: (e, _) => Center(child: Text('Error: $e')),
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
            Colors.purple,
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
          Colors.purple,
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
    final async = ref.watch(_enrolmentReportProvider(yearId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        final byClass = data['by_class'] as Map<String, int>;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReportHeader(
              'Enrolment Summary',
              yearLabel,
              Icons.school,
              Colors.indigo,
            ),
            const SizedBox(height: 8),
            // Export button
            ElevatedButton.icon(
              onPressed: () async {
                await ExportService.exportEnrolmentReportPdf(
                  yearLabel: yearLabel,
                  totalEnrolled: data['total_enrolled'] as int,
                  maleCount: data['male_count'] as int,
                  femaleCount: data['female_count'] as int,
                  activeInYear: data['active_in_year'] as int,
                  byClass: byClass,
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export to PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _StatCard(
              'Total Enrolled',
              '${data['total_enrolled']}',
              Icons.groups,
              Colors.indigo,
            ),
            const SizedBox(height: 8),
            _StatCard(
              'Male Students',
              '${data['male_count']}',
              Icons.male,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _StatCard(
              'Female Students',
              '${data['female_count']}',
              Icons.female,
              Colors.pink,
            ),
            const SizedBox(height: 8),
            _StatCard(
              'Active in Selected Year',
              '${data['active_in_year']}',
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
                    backgroundColor: Colors.indigo,
                    radius: 16,
                    child: Icon(Icons.class_, color: Colors.white, size: 14),
                  ),
                  title: Text(e.key),
                  trailing: Chip(
                    label: Text('${e.value}'),
                    backgroundColor: Colors.indigo.withValues(alpha: 0.1),
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
      error: (e, _) => Center(child: Text('Error: $e')),
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

  @override
  Widget build(BuildContext context) => Card(
    color: color.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              Text(subtitle, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: color,
        ),
      ),
    ),
  );
}
