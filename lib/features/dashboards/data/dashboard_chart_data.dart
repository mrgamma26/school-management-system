// lib/features/dashboards/data/dashboard_chart_data.dart
// Real, RLS-scoped data for the role dashboard charts. Every query runs as the
// signed-in user, caps the rows it reads and aggregates in memory. Nothing is
// estimated: when a query fails or returns nothing the chart shows its own
// "unavailable" / "No data yet" state.

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/supabase_client.dart';
import '../../../core/navigation/role_menus.dart' show canonicalRole;
import '../../../theme/app_tokens.dart';
import '../../../widgets/ui_charts.dart';

// ── Shared helpers ──────────────────────────────────────────────────────────

const _pageSize = 1000;
const _maxPages = 3;

/// Rows read for a chart. [capped] is true when the row limit was reached, so
/// older rows may be missing.
class CappedRows {
  final List<Map<String, dynamic>> rows;
  final bool capped;
  const CappedRows(this.rows, this.capped);
}

/// Reads up to [_maxPages] pages of [_pageSize] rows.
Future<CappedRows> _fetchPaged(
  Future<List<Map<String, dynamic>>> Function(int from, int to) page,
) async {
  final rows = <Map<String, dynamic>>[];
  for (var i = 0; i < _maxPages; i++) {
    final chunk = await page(i * _pageSize, (i + 1) * _pageSize - 1);
    rows.addAll(chunk);
    if (chunk.length < _pageSize) return CappedRows(rows, false);
  }
  return CappedRows(rows, true);
}

/// A to-one embed arrives as a Map; tolerate a one-element List too.
Map<String, dynamic>? _one(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
    return value.first as Map<String, dynamic>;
  }
  return null;
}

String _titleCase(String raw) => raw
    .replaceAll('_', ' ')
    .toLowerCase()
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Monday 00:00 of the week containing [d] (local time).
DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// The last [count] week starts, oldest first, ending with the current week.
List<DateTime> weekStarts(int count, [DateTime? now]) {
  final current = _mondayOf(now ?? DateTime.now());
  return [
    for (var i = count - 1; i >= 0; i--)
      DateTime(current.year, current.month, current.day - 7 * i),
  ];
}

/// The last [count] month starts, oldest first, ending with the current month.
List<DateTime> monthStarts(int count, [DateTime? now]) {
  final n = now ?? DateTime.now();
  return [
    for (var i = count - 1; i >= 0; i--) DateTime(n.year, n.month - i, 1),
  ];
}

String _weekLabel(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Super User ──────────────────────────────────────────────────────────────

/// System accounts grouped by role name.
final usersByRoleProvider = FutureProvider.autoDispose<List<ChartSlice>>((
  ref,
) async {
  final result = await _fetchPaged(
    (from, to) => supabase
        .from('systemuser')
        .select('role:role!fk_systemuser_role(rolename)')
        .order('userid')
        .range(from, to),
  );
  final counts = <String, int>{};
  for (final row in result.rows) {
    final name = _one(row['role'])?['rolename']?.toString();
    if (name == null || name.isEmpty) continue;
    final key = canonicalRole(name);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entries) ChartSlice(_titleCase(e.key), e.value.toDouble()),
  ];
});

/// Audit-log entries per week for the last 8 weeks (exact counts, no rows read).
final auditActivityProvider = FutureProvider.autoDispose<List<ChartPoint>>((
  ref,
) async {
  final starts = weekStarts(8);
  Future<int> countWeek(DateTime start) async {
    final end = DateTime(start.year, start.month, start.day + 7);
    final result = await supabase
        .from('auditlog')
        .select('auditid')
        .gte('createdat', start.toUtc().toIso8601String())
        .lt('createdat', end.toUtc().toIso8601String())
        .limit(0)
        .count(CountOption.exact);
    return result.count;
  }

  final counts = await Future.wait([for (final s in starts) countWeek(s)]);
  return [
    for (var i = 0; i < starts.length; i++)
      ChartPoint(_weekLabel(starts[i]), counts[i].toDouble()),
  ];
});

/// Stacked bars plus whether the row limit was hit.
class StackedChartData {
  final List<BarDatum> bars;
  final bool capped;
  const StackedChartData(this.bars, this.capped);
}

/// Email delivery status per week for the last 6 weeks. Only the status and
/// queue time are read; message bodies and addresses never leave the database.
final emailDeliveryProvider = FutureProvider.autoDispose<StackedChartData>((
  ref,
) async {
  final starts = weekStarts(6);
  final result = await _fetchPaged(
    (from, to) => supabase
        .from('email_delivery_log')
        .select('queued_at, status')
        .gte('queued_at', starts.first.toUtc().toIso8601String())
        .order('queued_at', ascending: false)
        .order('email_log_id')
        .range(from, to),
  );
  final buckets = [for (final _ in starts) <double>[0, 0, 0]];
  for (final row in result.rows) {
    final queued = DateTime.tryParse('${row['queued_at']}')?.toLocal();
    if (queued == null) continue;
    var index = -1;
    for (var i = 0; i < starts.length; i++) {
      if (!queued.isBefore(starts[i])) index = i;
    }
    if (index < 0) continue;
    final slot = switch ('${row['status']}'.toUpperCase()) {
      'SENT' => 0,
      'QUEUED' => 1,
      'FAILED' => 2,
      _ => -1,
    };
    if (slot >= 0) buckets[index][slot] += 1;
  }
  return StackedChartData([
    for (var i = 0; i < starts.length; i++)
      BarDatum(_weekLabel(starts[i]), buckets[i]),
  ], result.capped);
});

// ── Administrator ───────────────────────────────────────────────────────────

/// Enrolled students per form, from open class placements.
final studentsPerFormProvider = FutureProvider.autoDispose<List<ChartPoint>>((
  ref,
) async {
  final result = await _fetchPaged(
    (from, to) => supabase
        .from('studentclasshistory')
        .select('studentid, class(form), student(enrollmentstatus)')
        .isFilter('enddate', null)
        .order('historyid')
        .range(from, to),
  );
  final byForm = <String, Set<String>>{};
  for (final row in result.rows) {
    final status = _one(row['student'])?['enrollmentstatus']
        ?.toString()
        .toLowerCase();
    if (status != 'enrolled') continue;
    final form = _one(row['class'])?['form'];
    final key = form == null ? '' : '$form';
    byForm.putIfAbsent(key, () => <String>{}).add('${row['studentid']}');
  }
  final keys = byForm.keys.toList()
    ..sort((a, b) {
      if (a.isEmpty) return 1;
      if (b.isEmpty) return -1;
      final x = int.tryParse(a);
      final y = int.tryParse(b);
      if (x != null && y != null) return x.compareTo(y);
      return a.compareTo(b);
    });
  return [
    for (final k in keys)
      ChartPoint(
        k.isEmpty
            ? 'No form'
            : (int.tryParse(k) != null ? 'Form $k' : k),
        byForm[k]!.length.toDouble(),
      ),
  ];
});

/// Students grouped by enrolment status.
final enrolmentStatusProvider = FutureProvider.autoDispose<List<ChartSlice>>((
  ref,
) async {
  final result = await _fetchPaged(
    (from, to) => supabase
        .from('student')
        .select('enrollmentstatus')
        .order('studentid')
        .range(from, to),
  );
  final counts = <String, int>{};
  for (final row in result.rows) {
    final status = '${row['enrollmentstatus']}'.toLowerCase();
    if (status.isEmpty || status == 'null') continue;
    counts[status] = (counts[status] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entries) ChartSlice(_titleCase(e.key), e.value.toDouble()),
  ];
});

// ── Head Teacher and Teacher: marks ─────────────────────────────────────────

/// Recorded marks visible to the signed-in user (most recent first). Shared by
/// the subject-average, distribution and submission charts.
final gradeRowsProvider = FutureProvider.autoDispose<CappedRows>((ref) {
  return _fetchPaged(
    (from, to) => supabase
        .from('grade')
        .select(
          'score, submissionstatus, '
          'assessment(maxscore, classsubject(class(classroomname), subject(subjectname)))',
        )
        .not('score', 'is', null)
        .order('updatedat', ascending: false)
        .order('gradeid')
        .range(from, to),
  );
});

double? _percent(Map<String, dynamic> row) {
  final score = (row['score'] as num?)?.toDouble();
  final max = (_one(row['assessment'])?['maxscore'] as num?)?.toDouble();
  if (score == null || max == null || max <= 0) return null;
  return score / max * 100;
}

/// Points plus how many marks they were built from.
class CountedChartData {
  final List<ChartPoint> points;
  final int total;
  final bool capped;
  const CountedChartData(this.points, this.total, this.capped);
}

/// Average percentage per subject, best first (at most 10 subjects).
final subjectAveragesProvider =
    FutureProvider.autoDispose<CountedChartData>((ref) async {
      final result = await ref.watch(gradeRowsProvider.future);
      final bySubject = <String, List<double>>{};
      var used = 0;
      for (final row in result.rows) {
        final pct = _percent(row);
        if (pct == null) continue;
        final classSubject = _one(_one(row['assessment'])?['classsubject']);
        final name = _one(classSubject?['subject'])?['subjectname']?.toString();
        if (name == null || name.isEmpty) continue;
        bySubject.putIfAbsent(name, () => []).add(pct);
        used++;
      }
      final points = [
        for (final e in bySubject.entries)
          ChartPoint(
            e.key,
            double.parse(
              (e.value.reduce((a, b) => a + b) / e.value.length)
                  .toStringAsFixed(1),
            ),
          ),
      ]..sort((a, b) => b.value.compareTo(a.value));
      return CountedChartData(points.take(10).toList(), used, result.capped);
    });

/// Marks in ten percentage bands (0-9 ... 90-100).
final markDistributionProvider =
    FutureProvider.autoDispose<CountedChartData>((ref) async {
      final result = await ref.watch(gradeRowsProvider.future);
      final bins = List<double>.filled(10, 0);
      var used = 0;
      for (final row in result.rows) {
        final pct = _percent(row);
        if (pct == null) continue;
        final index = (pct / 10).floor().clamp(0, 9);
        bins[index] += 1;
        used++;
      }
      return CountedChartData(
        [
          for (var i = 0; i < 10; i++)
            ChartPoint(i == 9 ? '90-100' : '${i * 10}-${i * 10 + 9}', bins[i]),
        ],
        used,
        result.capped,
      );
    });

/// Share of recorded marks already submitted, per class (at most 8 classes).
final submissionByClassProvider =
    FutureProvider.autoDispose<List<ProgressDatum>>((ref) async {
      final result = await ref.watch(gradeRowsProvider.future);
      final submitted = <String, int>{};
      final total = <String, int>{};
      for (final row in result.rows) {
        final classSubject = _one(_one(row['assessment'])?['classsubject']);
        final name = _one(classSubject?['class'])?['classroomname']?.toString();
        if (name == null || name.isEmpty) continue;
        total[name] = (total[name] ?? 0) + 1;
        if ('${row['submissionstatus']}'.toUpperCase() == 'SUBMITTED') {
          submitted[name] = (submitted[name] ?? 0) + 1;
        }
      }
      final names = total.keys.toList()..sort();
      return [
        for (final name in names.take(8))
          ProgressDatum(
            name,
            (submitted[name] ?? 0) / total[name]!,
            '${submitted[name] ?? 0} of ${total[name]} submitted',
          ),
      ];
    });

// ── Head Teacher: progression ───────────────────────────────────────────────

Color _decisionColor(String decision) => switch (decision.toUpperCase()) {
  'APPROVED' || 'PROMOTED' => AppColors.success,
  'RETAINED' => AppColors.warning,
  'REJECTED' => AppColors.danger,
  _ => AppColors.primaryLight,
};

/// Progression review decisions on record.
final progressionDecisionsProvider =
    FutureProvider.autoDispose<List<ChartSlice>>((ref) async {
      final result = await _fetchPaged(
        (from, to) => supabase
            .from('progressionreview')
            .select('decision')
            .order('reviewid')
            .range(from, to),
      );
      final counts = <String, int>{};
      for (final row in result.rows) {
        final decision = '${row['decision']}'.toUpperCase();
        if (decision.isEmpty || decision == 'NULL') continue;
        counts[decision] = (counts[decision] ?? 0) + 1;
      }
      final entries = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return [
        for (final e in entries)
          ChartSlice(
            _titleCase(e.key),
            e.value.toDouble(),
            color: _decisionColor(e.key),
          ),
      ];
    });

// ── Accountant and Guardian: payments ───────────────────────────────────────

/// Payments of the last 6 months grouped by month and method.
class PaymentChartData {
  final List<ChartPoint> months;
  final List<ChartSlice> methods;
  final double total;
  final bool capped;
  const PaymentChartData(this.months, this.methods, this.total, this.capped);
}

PaymentChartData _summarisePayments(
  CappedRows result,
  List<DateTime> months, {
  required bool skipReversed,
}) {
  final sums = List<double>.filled(months.length, 0);
  final methods = <String, double>{};
  var total = 0.0;
  for (final row in result.rows) {
    if (skipReversed) {
      final reversal = row['payment_reversals'];
      final reversed =
          (reversal is Map && reversal.isNotEmpty) ||
          (reversal is List && reversal.isNotEmpty);
      if (reversed) continue;
    }
    final amount = (row['amount'] as num?)?.toDouble();
    final date = DateTime.tryParse('${row['paymentdate']}');
    if (amount == null || date == null) continue;
    var index = -1;
    for (var i = 0; i < months.length; i++) {
      if (!date.isBefore(months[i])) index = i;
    }
    if (index < 0) continue;
    sums[index] += amount;
    total += amount;
    final method = '${row['method'] ?? ''}';
    if (method.isNotEmpty) methods[method] = (methods[method] ?? 0) + amount;
  }
  final methodEntries = methods.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return PaymentChartData(
    [
      for (var i = 0; i < months.length; i++)
        ChartPoint(_monthNames[months[i].month - 1], sums[i]),
    ],
    [for (final e in methodEntries) ChartSlice(_titleCase(e.key), e.value)],
    total,
    result.capped,
  );
}

/// Staff view: recorded payments minus reversals, last 6 months.
final paymentSummaryProvider = FutureProvider.autoDispose<PaymentChartData>((
  ref,
) async {
  final months = monthStarts(6);
  final result = await _fetchPaged(
    (from, to) => supabase
        .from('payment')
        .select('amount, paymentdate, method, payment_reversals(reversal_id)')
        .gte('paymentdate', _isoDate(months.first))
        .order('paymentdate', ascending: false)
        .order('paymentid')
        .range(from, to),
  );
  return _summarisePayments(result, months, skipReversed: true);
});

/// Guardian view: payments RLS allows for linked children, last 6 months.
final guardianPaymentSummaryProvider =
    FutureProvider.autoDispose<PaymentChartData>((ref) async {
      final months = monthStarts(6);
      final result = await _fetchPaged(
        (from, to) => supabase
            .from('payment')
            .select('amount, paymentdate, method')
            .gte('paymentdate', _isoDate(months.first))
            .order('paymentdate', ascending: false)
            .order('paymentid')
            .range(from, to),
      );
      return _summarisePayments(result, months, skipReversed: false);
    });
