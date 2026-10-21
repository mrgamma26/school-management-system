import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/widgets/ui_charts.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

void main() {
  testWidgets('chart panel shows the empty state when there is no data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AsyncChartPanel<List<ChartSlice>>(
          title: 'Users by role',
          value: const AsyncValue.data(<ChartSlice>[]),
          isEmpty: (d) => d.isEmpty,
          builder: (d) => UiDonutChart(slices: d, description: 'x'),
        ),
      ),
    );
    expect(find.text('Users by role'), findsOneWidget);
    expect(find.text('No data yet'), findsOneWidget);
  });

  testWidgets('chart panel shows a quiet message on error', (tester) async {
    await tester.pumpWidget(
      _host(
        AsyncChartPanel<List<ChartSlice>>(
          title: 'Users by role',
          value: AsyncValue.error('boom', StackTrace.empty),
          isEmpty: (d) => d.isEmpty,
          builder: (d) => UiDonutChart(slices: d, description: 'x'),
        ),
      ),
    );
    expect(find.text('This chart is unavailable right now.'), findsOneWidget);
    expect(find.text('boom'), findsNothing);
  });

  testWidgets('donut renders legend values and a semantic summary', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const UiDonutChart(
          description: 'Accounts grouped by role',
          slices: [ChartSlice('Teacher', 6), ChartSlice('Guardian', 2)],
          centerValue: '8',
          centerCaption: 'accounts',
        ),
      ),
    );
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Guardian'), findsOneWidget);
    expect(find.text('6 · 75%'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Donut chart.*Teacher 6 \\(75%\\)')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('bar, line, histogram and progress list render with data', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            UiBarChart(
              description: 'Students per form',
              data: [
                BarDatum('Form 1', [30]),
                BarDatum('Form 2', [25]),
              ],
            ),
            UiBarChart(
              horizontal: true,
              maxValue: 100,
              description: 'Average by subject',
              data: [
                BarDatum('Maths', [72]),
              ],
            ),
            UiLineChart(
              description: 'Payments per month',
              points: [ChartPoint('Aug', 10), ChartPoint('Sep', 20)],
            ),
            UiHistogram(
              description: 'Marks',
              bins: [ChartPoint('0-9', 1), ChartPoint('10-19', 4)],
            ),
            UiProgressList(
              description: 'Submitted marks',
              items: [ProgressDatum('Form 1A', 0.5, '2 of 4 submitted')],
            ),
          ],
        ),
      ),
    );
    expect(find.text('2 of 4 submitted'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Bar chart.*Form 1 30')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Line chart.*Aug 10')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Histogram.*10-19: 4')), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  test('compactNumber and groupedInt format values', () {
    expect(compactNumber(850), '850');
    expect(compactNumber(1200), '1.2K');
    expect(compactNumber(3000000), '3M');
    expect(groupedInt(1248), '1,248');
  });
}
