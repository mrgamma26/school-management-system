// lib/features/dashboards/presentation/dashboard_charts.dart
// The chart panels shown at the top of each role dashboard. Every panel reads
// a provider from dashboard_chart_data.dart and renders the shared chart
// toolkit; each role gets its own chart family.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/ui_charts.dart';
import '../../../widgets/ui_kit.dart' show formatMwk;
import '../data/dashboard_chart_data.dart';

/// Super User: users by role, audit activity, email delivery.
List<Widget> superUserCharts() => const [
  _UsersByRoleChart(),
  _AuditActivityChart(),
  _EmailDeliveryChart(),
];

/// Administrator: students per form, enrolment status.
List<Widget> administratorCharts() => const [
  _StudentsPerFormChart(),
  _EnrolmentStatusChart(),
];

/// Head Teacher: subject averages, progression decisions.
List<Widget> headTeacherCharts() => const [
  _SubjectAverageChart(),
  _ProgressionDecisionsChart(),
];

/// Teacher: mark distribution, submission progress per class.
List<Widget> teacherCharts() => const [
  _MarkDistributionChart(),
  _SubmissionByClassChart(),
];

/// Accountant: payments per month, payments by method.
List<Widget> accountantCharts() => const [
  _PaymentsPerMonthChart(),
  _PaymentMethodsChart(),
];

/// Guardian: payments per month for linked children.
List<Widget> guardianCharts() => const [_GuardianPaymentsChart()];

String _marksNote(CountedChartData d) => d.capped
    ? 'Latest ${groupedInt(d.total.toDouble())} marks'
    : '${groupedInt(d.total.toDouble())} marks';

String _mwk(double v) => formatMwk(v, decimals: 0);

// ── Super User ──────────────────────────────────────────────────────────────

class _UsersByRoleChart extends ConsumerWidget {
  const _UsersByRoleChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<List<ChartSlice>>(
      title: 'Users by role',
      note: 'All accounts',
      value: ref.watch(usersByRoleProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiDonutChart(
        slices: d,
        description: 'Accounts grouped by role',
        centerValue: groupedInt(d.fold<double>(0, (a, s) => a + s.value)),
        centerCaption: 'accounts',
      ),
    );
  }
}

class _AuditActivityChart extends ConsumerWidget {
  const _AuditActivityChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<List<ChartPoint>>(
      title: 'Audit activity',
      note: 'Entries per week, last 8 weeks',
      value: ref.watch(auditActivityProvider),
      isEmpty: (d) => d.every((p) => p.value <= 0),
      builder: (d) => UiLineChart(
        points: d,
        description: 'Audit log entries per week, weeks starting on the date shown',
      ),
    );
  }
}

class _EmailDeliveryChart extends ConsumerWidget {
  const _EmailDeliveryChart();

  static const _series = [
    ChartSeries('Sent', AppColors.success),
    ChartSeries('Queued', AppColors.warning),
    ChartSeries('Failed', AppColors.danger),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<StackedChartData>(
      title: 'Email delivery',
      note: 'Per week, last 6 weeks',
      noteOf: (d) => d.capped ? 'Latest 3,000 emails, last 6 weeks' : null,
      value: ref.watch(emailDeliveryProvider),
      isEmpty: (d) => d.bars.every((b) => b.total <= 0),
      builder: (d) => UiBarChart(
        data: d.bars,
        series: _series,
        description: 'Emails per week by delivery status, weeks starting on the date shown',
      ),
    );
  }
}

// ── Administrator ───────────────────────────────────────────────────────────

class _StudentsPerFormChart extends ConsumerWidget {
  const _StudentsPerFormChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<List<ChartPoint>>(
      title: 'Students per form',
      note: 'Enrolled learners',
      value: ref.watch(studentsPerFormProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiBarChart(
        data: [for (final p in d) BarDatum.single(p.label, p.value)],
        description: 'Enrolled students in each form',
      ),
    );
  }
}

class _EnrolmentStatusChart extends ConsumerWidget {
  const _EnrolmentStatusChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<List<ChartSlice>>(
      title: 'Enrolment status',
      note: 'All student records',
      value: ref.watch(enrolmentStatusProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiDonutChart(
        slices: d,
        description: 'Students by enrolment status',
        centerValue: groupedInt(d.fold<double>(0, (a, s) => a + s.value)),
        centerCaption: 'students',
      ),
    );
  }
}

// ── Head Teacher ────────────────────────────────────────────────────────────

class _SubjectAverageChart extends ConsumerWidget {
  const _SubjectAverageChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<CountedChartData>(
      title: 'Average by subject',
      note: 'Percent of marks available',
      noteOf: _marksNote,
      value: ref.watch(subjectAveragesProvider),
      isEmpty: (d) => d.points.isEmpty,
      builder: (d) => UiBarChart(
        horizontal: true,
        maxValue: 100,
        data: [for (final p in d.points) BarDatum.single(p.label, p.value)],
        format: (v) => '${v.toStringAsFixed(1)}%',
        labelFormat: (v) => '${v.round()}%',
        description: 'Average mark in percent for each subject',
      ),
    );
  }
}

class _ProgressionDecisionsChart extends ConsumerWidget {
  const _ProgressionDecisionsChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<List<ChartSlice>>(
      title: 'Progression decisions',
      note: 'Reviews on record',
      value: ref.watch(progressionDecisionsProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiDonutChart(
        slices: d,
        description: 'Progression review decisions',
        centerValue: groupedInt(d.fold<double>(0, (a, s) => a + s.value)),
        centerCaption: 'reviews',
      ),
    );
  }
}

// ── Teacher ─────────────────────────────────────────────────────────────────

class _MarkDistributionChart extends ConsumerWidget {
  const _MarkDistributionChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<CountedChartData>(
      title: 'Mark distribution',
      note: 'Bands of 10 percent',
      noteOf: _marksNote,
      value: ref.watch(markDistributionProvider),
      isEmpty: (d) => d.total == 0,
      builder: (d) => UiHistogram(
        bins: d.points,
        description: 'Number of recorded marks in each ten percent band',
      ),
    );
  }
}

class _SubmissionByClassChart extends ConsumerWidget {
  const _SubmissionByClassChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<List<ProgressDatum>>(
      title: 'Marks submitted by class',
      note: 'Recorded marks',
      value: ref.watch(submissionByClassProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiProgressList(
        items: d,
        description: 'Share of recorded marks already submitted, per class',
      ),
    );
  }
}

// ── Accountant ──────────────────────────────────────────────────────────────

class _PaymentsPerMonthChart extends ConsumerWidget {
  const _PaymentsPerMonthChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<PaymentChartData>(
      title: 'Payments per month',
      note: 'Last 6 months, reversals excluded',
      noteOf: (d) => 'Last 6 months · ${_mwk(d.total)}${d.capped ? ' (latest rows only)' : ''}',
      value: ref.watch(paymentSummaryProvider),
      isEmpty: (d) => d.total <= 0,
      builder: (d) => UiLineChart(
        points: d.months,
        format: _mwk,
        labelFormat: compactNumber,
        description: 'Amount collected in each month',
      ),
    );
  }
}

class _PaymentMethodsChart extends ConsumerWidget {
  const _PaymentMethodsChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<PaymentChartData>(
      title: 'Payments by method',
      note: 'Last 6 months',
      value: ref.watch(paymentSummaryProvider),
      isEmpty: (d) => d.methods.isEmpty,
      builder: (d) => UiDonutChart(
        slices: d.methods,
        format: _mwk,
        description: 'Amount collected by payment method',
        centerValue: compactNumber(d.total),
        centerCaption: 'MWK',
      ),
    );
  }
}

// ── Guardian ────────────────────────────────────────────────────────────────

class _GuardianPaymentsChart extends ConsumerWidget {
  const _GuardianPaymentsChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<PaymentChartData>(
      title: 'Payments per month',
      note: 'Linked children, last 6 months',
      value: ref.watch(guardianPaymentSummaryProvider),
      isEmpty: (d) => d.total <= 0,
      builder: (d) => UiBarChart(
        data: [for (final p in d.months) BarDatum.single(p.label, p.value)],
        format: _mwk,
        labelFormat: compactNumber,
        description: 'Fees paid in each month for your linked children',
      ),
    );
  }
}
