// lib/widgets/ui_charts.dart
// Dependency-free chart toolkit for the role dashboards (CustomPaint only).
//
// Rules: charts take plain data, never invent numbers, show "No data yet" when
// there is nothing to draw, and describe their values through Semantics.
// Series use the school blue palette; green / amber / red are only passed in by
// callers when a series really is a status (sent / failed, approved / rejected).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_tokens.dart';
import 'ui_kit.dart';

// ── Data ────────────────────────────────────────────────────────────────────

/// One labelled value (line point, histogram bin).
class ChartPoint {
  final String label;
  final double value;
  const ChartPoint(this.label, this.value);
}

/// One donut slice. [color] falls back to the blue palette by position.
class ChartSlice {
  final String label;
  final double value;
  final Color? color;
  const ChartSlice(this.label, this.value, {this.color});
}

/// Name and colour of one bar series (needed for stacked bars and legends).
class ChartSeries {
  final String name;
  final Color color;
  const ChartSeries(this.name, this.color);
}

/// One bar (or one stack): a value per series.
class BarDatum {
  final String label;
  final List<double> values;
  const BarDatum(this.label, this.values);

  /// Single-series bar.
  BarDatum.single(this.label, double value) : values = [value];

  double get total => values.fold(0.0, (a, b) => a + b);
}

/// One row of a progress list. [fraction] is 0..1.
class ProgressDatum {
  final String label;
  final double fraction;
  final String caption;
  const ProgressDatum(this.label, this.fraction, this.caption);
}

/// Blue-950 / 700 / 500 / 200 plus a neutral for the fifth and later series.
const List<Color> chartPalette = [
  AppColors.navy,
  AppColors.primary,
  AppColors.primaryLight,
  AppColors.blue200,
  AppColors.textDisabled,
];

Color chartColor(int index) => chartPalette[index % chartPalette.length];

// ── Number helpers ──────────────────────────────────────────────────────────

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// "1.2K", "3.4M", "850" - compact tick labels for axes.
String compactNumber(double v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1000000) return '$sign${_trim(a / 1000000)}M';
  if (a >= 1000) return '$sign${_trim(a / 1000)}K';
  return '$sign${_trim(a)}';
}

/// "1,248" - whole numbers with grouped thousands.
String groupedInt(double v) => v
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Axis with "nice" tick steps covering [maxValue].
class _Axis {
  final double step;
  final int intervals;
  const _Axis(this.step, this.intervals);

  double get max => step * intervals;

  static _Axis nice(double maxValue, {int target = 4}) {
    if (maxValue <= 0) return const _Axis(1, 1);
    final raw = maxValue / target;
    final mag = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final norm = raw / mag;
    final niceNorm = norm <= 1
        ? 1
        : norm <= 2
        ? 2
        : norm <= 5
        ? 5
        : 10;
    final step = niceNorm * mag;
    final n = math.max(1, (maxValue / step).ceil());
    return _Axis(step, n);
  }

  static _Axis fixed(double maxValue, {int intervals = 4}) =>
      _Axis(maxValue / intervals, intervals);
}

TextPainter _text(
  String s, {
  double size = 10,
  Color color = AppColors.textSecondary,
  FontWeight weight = FontWeight.w700,
  double maxWidth = double.infinity,
}) {
  return TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: size, color: color, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
}

// ── Panel + states ──────────────────────────────────────────────────────────

/// A [Panel] with a title and a small muted note, the frame of every chart.
class ChartPanel extends StatelessWidget {
  final String title;
  final String? note;
  final Widget child;

  const ChartPanel({super.key, required this.title, this.note, required this.child});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: title,
      trailing: note == null ? null : Flexible(child: PanelNote(note!)),
      child: child,
    );
  }
}

/// Quiet one-line state used for "No data yet" and "unavailable".
class ChartMessage extends StatelessWidget {
  final String text;
  final IconData icon;
  final double height;

  const ChartMessage(
    this.text, {
    super.key,
    this.icon = Icons.insights_outlined,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: AppColors.textDisabled),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chart panel driven by an [AsyncValue]: a static skeleton while loading, a
/// quiet "unavailable" message on error, "No data yet" when [isEmpty], else
/// [builder]. Nothing here ever throws or fabricates values.
class AsyncChartPanel<T> extends StatelessWidget {
  final String title;
  final String? note;
  final String? Function(T data)? noteOf;
  final AsyncValue<T> value;
  final bool Function(T data) isEmpty;
  final Widget Function(T data) builder;

  const AsyncChartPanel({
    super.key,
    required this.title,
    required this.value,
    required this.isEmpty,
    required this.builder,
    this.note,
    this.noteOf,
  });

  @override
  Widget build(BuildContext context) {
    final String? shownNote;
    final Widget body;
    final data = value.asData?.value;
    if (value.hasError && data == null) {
      shownNote = note;
      body = const ChartMessage(
        'This chart is unavailable right now.',
        icon: Icons.cloud_off_outlined,
      );
    } else if (data == null && value.isLoading) {
      shownNote = note;
      body = Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    } else if (data == null || isEmpty(data)) {
      shownNote = note;
      body = const ChartMessage('No data yet');
    } else {
      shownNote = noteOf?.call(data) ?? note;
      body = builder(data);
    }
    return ChartPanel(title: title, note: shownNote, child: body);
  }
}

/// Wraps a chart with a spoken summary and hides the painted details from the
/// accessibility tree.
class _ChartSemantics extends StatelessWidget {
  final String label;
  final Widget child;
  const _ChartSemantics({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: ExcludeSemantics(child: child),
  );
}

/// Dot + label pairs under a chart.
class ChartLegend extends StatelessWidget {
  final List<ChartSeries> items;
  const ChartLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Line / area chart ───────────────────────────────────────────────────────

/// Line chart with an optional area fill. Values start at zero.
class UiLineChart extends StatelessWidget {
  final List<ChartPoint> points;

  /// Spoken prefix, e.g. "Payments per month".
  final String description;
  final String Function(double value) format;
  final String Function(double value)? axisFormat;

  /// Shorter text for the labels above the points (defaults to [format]).
  final String Function(double value)? labelFormat;
  final bool area;
  final double height;

  const UiLineChart({
    super.key,
    required this.points,
    required this.description,
    this.format = groupedInt,
    this.axisFormat,
    this.labelFormat,
    this.area = true,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final summary = points
        .map((p) => '${p.label} ${format(p.value)}')
        .join(', ');
    return _ChartSemantics(
      label: 'Line chart. $description. $summary.',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(
            points,
            labelFormat ?? format,
            axisFormat ?? compactNumber,
            area,
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<ChartPoint> points;
  final String Function(double) format;
  final String Function(double) axisFormat;
  final bool area;

  _LinePainter(this.points, this.format, this.axisFormat, this.area);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 46.0, right = 12.0, top = 20.0, bottom = 24.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxV = points.map((p) => p.value).fold<double>(0, math.max);
    final axis = _Axis.nice(maxV);

    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var i = 0; i <= axis.intervals; i++) {
      final y = plot.bottom - plot.height * i / axis.intervals;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final t = _text(axisFormat(axis.step * i));
      t.paint(canvas, Offset(plot.left - 6 - t.width, y - t.height / 2));
    }

    final n = points.length;
    final xStart = plot.left + 8;
    final xEnd = plot.right - 8;
    double xAt(int i) => n == 1 ? (xStart + xEnd) / 2 : xStart + (xEnd - xStart) * i / (n - 1);
    double yAt(double v) => plot.bottom - plot.height * (v / axis.max).clamp(0.0, 1.0);

    final line = Path();
    for (var i = 0; i < n; i++) {
      final p = Offset(xAt(i), yAt(points[i].value));
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }
    if (area && n > 1) {
      final fill = Path.from(line)
        ..lineTo(xAt(n - 1), plot.bottom)
        ..lineTo(xAt(0), plot.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()..shader = AppGradients.chartPrimary.createShader(plot),
      );
    }
    if (n > 1) {
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    final step = math.max(1, (n / 8).ceil());
    for (var i = 0; i < n; i++) {
      final c = Offset(xAt(i), yAt(points[i].value));
      canvas.drawCircle(c, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        c,
        4.5,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (n <= 6) {
        final t = _text(
          format(points[i].value),
          color: AppColors.textPrimary,
          weight: FontWeight.w800,
        );
        final dx = (c.dx - t.width / 2).clamp(0.0, math.max(0.0, size.width - t.width)).toDouble();
        t.paint(canvas, Offset(dx, c.dy - 18));
      }
      if (i % step == 0) {
        final slot = n == 1 ? plot.width : plot.width / n;
        final t = _text(points[i].label, maxWidth: math.max(24, slot));
        final dx = (c.dx - t.width / 2).clamp(0.0, math.max(0.0, size.width - t.width)).toDouble();
        t.paint(canvas, Offset(dx, plot.bottom + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

// ── Bar charts (vertical, horizontal, stacked, histogram) ───────────────────

/// Bar chart. One series = plain bars, several = stacked. [horizontal] lays
/// the bars out as rows with the labels on the left.
class UiBarChart extends StatelessWidget {
  final List<BarDatum> data;
  final List<ChartSeries> series;
  final bool horizontal;
  final String description;
  final String Function(double value) format;
  final String Function(double value)? axisFormat;

  /// Shorter text for the value shown on each bar (defaults to [format]).
  final String Function(double value)? labelFormat;

  /// Fixed axis maximum (e.g. 100 for percentages); otherwise derived.
  final double? maxValue;
  final double height;

  const UiBarChart({
    super.key,
    required this.data,
    required this.description,
    this.series = const [ChartSeries('Value', AppColors.primary)],
    this.horizontal = false,
    this.format = groupedInt,
    this.axisFormat,
    this.labelFormat,
    this.maxValue,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final summary = data.map((d) {
      if (series.length == 1) return '${d.label} ${format(d.values.first)}';
      final parts = [
        for (var i = 0; i < series.length && i < d.values.length; i++)
          '${series[i].name} ${format(d.values[i])}',
      ];
      return '${d.label}: ${parts.join(', ')}';
    }).join('; ');
    final chartHeight = horizontal ? data.length * 30.0 + 4 : height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartSemantics(
          label:
              '${series.length > 1 ? 'Stacked bar chart' : 'Bar chart'}. $description. $summary.',
          child: SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: horizontal
                  ? _HBarPainter(data, series, labelFormat ?? format, maxValue)
                  : _VBarPainter(
                      data,
                      series,
                      labelFormat ?? format,
                      axisFormat ?? compactNumber,
                      maxValue,
                      0.34,
                    ),
            ),
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 10),
          ExcludeSemantics(child: ChartLegend(items: series)),
        ],
      ],
    );
  }
}

/// Histogram: adjacent bars for consecutive value bands. [bins] are labelled
/// by band (e.g. "40-49").
class UiHistogram extends StatelessWidget {
  final List<ChartPoint> bins;
  final String description;
  final double height;

  const UiHistogram({
    super.key,
    required this.bins,
    required this.description,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final summary = bins.map((b) => '${b.label}: ${groupedInt(b.value)}').join(', ');
    return _ChartSemantics(
      label: 'Histogram. $description. $summary.',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _VBarPainter(
            [for (final b in bins) BarDatum.single(b.label, b.value)],
            const [ChartSeries('Count', AppColors.primary)],
            groupedInt,
            compactNumber,
            null,
            0.08,
          ),
        ),
      ),
    );
  }
}

class _VBarPainter extends CustomPainter {
  final List<BarDatum> data;
  final List<ChartSeries> series;
  final String Function(double) format;
  final String Function(double) axisFormat;
  final double? maxValue;
  final double gapFraction;

  _VBarPainter(
    this.data,
    this.series,
    this.format,
    this.axisFormat,
    this.maxValue,
    this.gapFraction,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const left = 40.0, right = 8.0, top = 20.0, bottom = 24.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxTotal = data.map((d) => d.total).fold<double>(0, math.max);
    final axis = maxValue != null ? _Axis.fixed(maxValue!) : _Axis.nice(maxTotal);

    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var i = 0; i <= axis.intervals; i++) {
      final y = plot.bottom - plot.height * i / axis.intervals;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final t = _text(axisFormat(axis.step * i));
      t.paint(canvas, Offset(plot.left - 6 - t.width, y - t.height / 2));
    }

    final slot = plot.width / data.length;
    final barW = math.min(56.0, slot * (1 - gapFraction));
    for (var i = 0; i < data.length; i++) {
      final cx = plot.left + slot * (i + 0.5);
      var base = plot.bottom;
      final d = data[i];
      // Find the topmost non-zero segment so only it gets rounded corners.
      var topIndex = -1;
      for (var s = 0; s < d.values.length; s++) {
        if (d.values[s] > 0) topIndex = s;
      }
      for (var s = 0; s < d.values.length; s++) {
        final v = d.values[s];
        if (v <= 0) continue;
        final h = plot.height * (v / axis.max).clamp(0.0, 1.0);
        final rect = Rect.fromLTWH(cx - barW / 2, base - h, barW, h);
        final color = s < series.length ? series[s].color : chartColor(s);
        final rr = s == topIndex
            ? RRect.fromRectAndCorners(
                rect,
                topLeft: const Radius.circular(4),
                topRight: const Radius.circular(4),
              )
            : RRect.fromRectXY(rect, 0, 0);
        canvas.drawRRect(rr, Paint()..color = color);
        if (s > 0) {
          canvas.drawLine(
            Offset(rect.left, rect.bottom),
            Offset(rect.right, rect.bottom),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1,
          );
        }
        base -= h;
      }
      if (d.total > 0 && slot >= 26) {
        final t = _text(
          format(d.total),
          color: AppColors.textPrimary,
          weight: FontWeight.w800,
          maxWidth: slot,
        );
        t.paint(canvas, Offset(cx - t.width / 2, base - 16));
      }
      final label = _text(d.label, maxWidth: slot);
      label.paint(canvas, Offset(cx - label.width / 2, plot.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _VBarPainter old) => true;
}

class _HBarPainter extends CustomPainter {
  final List<BarDatum> data;
  final List<ChartSeries> series;
  final String Function(double) format;
  final double? maxValue;

  _HBarPainter(this.data, this.series, this.format, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final labelW = math.min(130.0, size.width * 0.34);
    final plotLeft = labelW + 8;
    final plotRight = size.width - 52;
    final plotW = plotRight - plotLeft;
    if (plotW <= 0) return;
    final maxTotal = data.map((d) => d.total).fold<double>(0, math.max);
    final axisMax = maxValue ?? (maxTotal <= 0 ? 1.0 : maxTotal);
    const rowH = 30.0;
    const barH = 14.0;
    for (var i = 0; i < data.length; i++) {
      final cy = rowH * i + rowH / 2 + 2;
      final d = data[i];
      final label = _text(
        d.label,
        size: 11.5,
        color: AppColors.textPrimary,
        maxWidth: labelW,
      );
      label.paint(canvas, Offset(0, cy - label.height / 2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(plotLeft, cy - barH / 2, plotW, barH),
          const Radius.circular(5),
        ),
        Paint()..color = AppColors.surfaceVariant,
      );
      var x = plotLeft;
      for (var s = 0; s < d.values.length; s++) {
        final v = d.values[s];
        if (v <= 0) continue;
        final w = plotW * (v / axisMax).clamp(0.0, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, cy - barH / 2, w, barH),
            const Radius.circular(5),
          ),
          Paint()..color = s < series.length ? series[s].color : chartColor(s),
        );
        x += w;
      }
      final value = _text(
        format(d.total),
        size: 11,
        color: AppColors.textPrimary,
        weight: FontWeight.w800,
        maxWidth: 48,
      );
      value.paint(canvas, Offset(plotRight + 6, cy - value.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _HBarPainter old) => true;
}

// ── Donut ───────────────────────────────────────────────────────────────────

/// Donut with a legend (label, value and share). Slices with a zero value are
/// left out.
class UiDonutChart extends StatelessWidget {
  final List<ChartSlice> slices;
  final String description;
  final String Function(double value) format;
  final String? centerValue;
  final String? centerCaption;

  const UiDonutChart({
    super.key,
    required this.slices,
    required this.description,
    this.format = groupedInt,
    this.centerValue,
    this.centerCaption,
  });

  @override
  Widget build(BuildContext context) {
    final shown = slices.where((s) => s.value > 0).toList();
    final total = shown.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return const ChartMessage('No data yet');
    final colors = [
      for (var i = 0; i < shown.length; i++) shown[i].color ?? chartColor(i),
    ];
    final summary = shown
        .map((s) => '${s.label} ${format(s.value)} (${(s.value / total * 100).round()}%)')
        .join(', ');

    final ring = SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(150, 150),
            painter: _DonutPainter([for (final s in shown) s.value], colors),
          ),
          if (centerValue != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerValue!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (centerCaption != null)
                  Text(
                    centerCaption!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors[i],
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shown[i].label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${format(shown[i].value)} · ${(shown[i].value / total * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return _ChartSemantics(
      label: 'Donut chart. $description. $summary.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              children: [ring, const SizedBox(height: 12), legend],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: 18),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _DonutPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    const stroke = 24.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - stroke / 2,
    );
    final gap = values.length > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0.0, sweep - gap),
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

// ── Progress list ───────────────────────────────────────────────────────────

/// Rows of "label ... caption" over a filled track.
class UiProgressList extends StatelessWidget {
  final List<ProgressDatum> items;
  final String description;

  const UiProgressList({super.key, required this.items, required this.description});

  @override
  Widget build(BuildContext context) {
    final summary = items.map((i) => '${i.label} ${i.caption}').join('; ');
    return _ChartSemantics(
      label: 'Progress list. $description. $summary.',
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.caption,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 9,
                      color: AppColors.surfaceVariant,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: item.fraction.clamp(0.0, 1.0),
                        child: Container(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
