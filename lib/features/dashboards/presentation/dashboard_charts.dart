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
      title: 'System user accounts by role',
      note: 'Active and inactive sign-in accounts for staff and guardians',
      value: ref.watch(usersByRoleProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiDonutChart(
        slices: d,
        description:
            'Number of sign-in accounts held by each role: Super User, Administrator, Head Teacher, Teacher, Accountant and Guardian',
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
      title: 'Recorded system actions per week',
      note: 'Audit log entries (creations, changes, decisions), last 8 weeks',
      value: ref.watch(auditActivityProvider),
      isEmpty: (d) => d.every((p) => p.value <= 0),
      builder: (d) => UiLineChart(
        points: d,
        description:
            'Audit log entries per week, weeks starting on the date shown',
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
      title: 'Notification emails sent to guardians and staff per week',
      note: 'Sent, failed and pending emails, last 6 weeks',
      noteOf: (d) => d.capped ? 'Latest 3,000 emails, last 6 weeks' : null,
      value: ref.watch(emailDeliveryProvider),
      isEmpty: (d) => d.bars.every((b) => b.total <= 0),
      builder: (d) => UiBarChart(
        data: d.bars,
        series: _series,
        description:
            'Emails per week by delivery status, weeks starting on the date shown',
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
      title: 'Enrolled students in each form this school year',
      note: 'Active students placed in Form 1, Form 2, Form 3 and Form 4',
      value: ref.watch(studentsPerFormProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiBarChart(
        data: [for (final p in d) BarDatum.single(p.label, p.value)],
        description:
            'Number of active students placed in each form (Form 1 to Form 4) this school year',
      ),
    );
  }
}

class _EnrolmentStatusChart extends ConsumerWidget {
  const _EnrolmentStatusChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<List<ChartSlice>>(
      title: 'Students by enrolment status',
      note:
          'All student records: active, graduated, withdrawn and other statuses',
      value: ref.watch(enrolmentStatusProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiDonutChart(
        slices: d,
        description:
            'Number of student records in each enrolment status: active, graduated, withdrawn and others',
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
      title: 'Average student mark in each subject',
      note:
          'Average percentage across all recorded assessment marks per subject',
      noteOf: _marksNote,
      value: ref.watch(subjectAveragesProvider),
      isEmpty: (d) => d.points.isEmpty,
      builder: (d) => UiBarChart(
        horizontal: true,
        maxValue: 100,
        data: [for (final p in d.points) BarDatum.single(p.label, p.value)],
        format: (v) => '${v.toStringAsFixed(1)}%',
        labelFormat: (v) => '${v.round()}%',
        description:
            'Average mark, in percent of the maximum score, of all students in each subject',
      ),
    );
  }
}

class _ProgressionDecisionsChart extends ConsumerWidget {
  const _ProgressionDecisionsChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<List<ChartSlice>>(
      title: 'Year-end progression decisions by the Head Teacher',
      note: 'Students promoted, retained or awaiting a decision',
      value: ref.watch(progressionDecisionsProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiDonutChart(
        slices: d,
        description:
            'Number of year-end progression reviews that are promoted, retained or still pending a Head Teacher decision',
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
      title: 'Spread of student assessment marks',
      note: 'Number of marks in each 10 percent band (0-9, 10-19 ... 90-100)',
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
      title: 'Teacher marks submitted to the Head Teacher, per class',
      note: 'Share of entered marks already submitted for review, by class',
      value: ref.watch(submissionByClassProvider),
      isEmpty: (d) => d.isEmpty,
      builder: (d) => UiProgressList(
        items: d,
        description:
            'Percentage of the marks teachers have entered that are already submitted to the Head Teacher, for each class',
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
      title: 'School fee payments received from guardians per month',
      note:
          'Total MWK collected for all students each month, last 6 months, reversed payments excluded',
      noteOf: (d) =>
          'Last 6 months · ${_mwk(d.total)}${d.capped ? ' (latest rows only)' : ''}',
      value: ref.watch(paymentSummaryProvider),
      isEmpty: (d) => d.total <= 0,
      builder: (d) => UiLineChart(
        points: d.months,
        format: _mwk,
        labelFormat: compactNumber,
        description:
            'Total school fees in Malawi Kwacha paid by guardians for all students in each of the last six months',
      ),
    );
  }
}

class _PaymentMethodsChart extends ConsumerWidget {
  const _PaymentMethodsChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncChartPanel<PaymentChartData>(
      title: 'School fee payments by payment method',
      note:
          'MWK received by cash, bank deposit and mobile money, last 6 months',
      value: ref.watch(paymentSummaryProvider),
      isEmpty: (d) => d.methods.isEmpty,
      builder: (d) => UiDonutChart(
        slices: d.methods,
        format: _mwk,
        description:
            'Total school fees in Malawi Kwacha received through each payment method over the last six months',
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
      title: 'Your school fee payments for your children per month',
      note:
          'MWK you paid each month for the students linked to you, last 6 months',
      value: ref.watch(guardianPaymentSummaryProvider),
      isEmpty: (d) => d.total <= 0,
      builder: (d) => UiBarChart(
        data: [for (final p in d.months) BarDatum.single(p.label, p.value)],
        format: _mwk,
        labelFormat: compactNumber,
        description:
            'Total school fees in Malawi Kwacha you paid in each of the last six months for the students linked to your account',
      ),
    );
  }
}
