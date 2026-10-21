/// Pure mark-sheet rules shared by the teacher's "Enter marks" workspace and
/// the Head Teacher's review workspace. No Flutter or Supabase imports, so the
/// rules are unit-testable.
library;

/// Pass mark used for pass-rate figures: half of the maximum score. It is the
/// same boundary as grade D in [gradeLetter] and the report card.
const double passFraction = 0.5;

/// Letter grade for a [percent] (0-100), using the scale already used by the
/// guardian report card: A 80+, B 70+, C 60+, D 50+, otherwise F.
String gradeLetter(double percent) {
  if (percent >= 80) return 'A';
  if (percent >= 70) return 'B';
  if (percent >= 60) return 'C';
  if (percent >= 50) return 'D';
  return 'F';
}

/// How one student's cell on a mark sheet should be read.
enum MarkState {
  /// A numeric score inside 0..max.
  valid,

  /// Recorded as absent: accounted for, but there is no mark.
  absent,

  /// Nothing entered yet.
  missing,

  /// Typed text that is not a usable score. It is flagged and never saved.
  invalid,
}

/// The reading of one mark cell.
class MarkCheck {
  final MarkState state;
  final double? score;
  final String? message;

  const MarkCheck(this.state, {this.score, this.message});

  bool get isValid => state == MarkState.valid;
}

/// Reads [raw] (what the teacher typed) against [maxScore].
///
/// [absent] wins over the typed text: an absent student has no mark.
/// Same numeric rules as `validateScore` in the grade repository: numeric,
/// not negative, not above the maximum.
MarkCheck checkMark(String raw, double maxScore, {bool absent = false}) {
  if (absent) return const MarkCheck(MarkState.absent);
  final text = raw.trim();
  if (text.isEmpty) return const MarkCheck(MarkState.missing);
  final score = double.tryParse(text);
  if (score == null || score.isNaN || score.isInfinite) {
    return const MarkCheck(
      MarkState.invalid,
      message: 'Score must be numeric.',
    );
  }
  if (score < 0) {
    return const MarkCheck(
      MarkState.invalid,
      message: 'Score cannot be negative.',
    );
  }
  if (score > maxScore) {
    return MarkCheck(
      MarkState.invalid,
      message: 'Enter 0 to ${formatScore(maxScore)}.',
    );
  }
  return MarkCheck(MarkState.valid, score: score);
}

/// Reading of a mark already stored in the database.
MarkCheck checkStoredMark({
  required double? score,
  required String status,
  required double maxScore,
}) {
  if (status.toUpperCase() == 'ABSENT') {
    return const MarkCheck(MarkState.absent);
  }
  if (score == null) return const MarkCheck(MarkState.missing);
  return checkMark(formatScore(score), maxScore);
}

/// "74", "55.5": no trailing ".0".
String formatScore(num value) {
  final v = value.toDouble();
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final text = v.toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

double _round1(double value) => (value * 10).roundToDouble() / 10;

/// Totals for one assessment's roster.
class SheetStats {
  final int total;
  final int valid;
  final int absent;
  final int missing;
  final int invalid;

  /// Average of the valid marks as a percentage of the maximum (1 decimal),
  /// or null when no valid mark exists.
  final double? averagePercent;
  final double? highest;
  final double? lowest;

  /// Share of valid marks at or above the pass mark, in percent (whole number).
  final int? passRatePercent;

  const SheetStats({
    required this.total,
    required this.valid,
    required this.absent,
    required this.missing,
    required this.invalid,
    required this.averagePercent,
    required this.highest,
    required this.lowest,
    required this.passRatePercent,
  });

  /// Students whose mark is entered or who are recorded absent.
  int get accounted => valid + absent;

  /// 0..1, for a progress meter.
  double get completion => total == 0 ? 0 : accounted / total;

  /// True when nobody is missing or invalid, so the sheet can be submitted.
  bool get ready => total > 0 && missing == 0 && invalid == 0;
}

/// Totals for [checks] (one per rostered student) out of [maxScore].
SheetStats computeSheetStats(Iterable<MarkCheck> checks, double maxScore) {
  var total = 0, valid = 0, absent = 0, missing = 0, invalid = 0, passed = 0;
  var sum = 0.0;
  double? high, low;
  for (final check in checks) {
    total++;
    switch (check.state) {
      case MarkState.valid:
        valid++;
        final score = check.score!;
        sum += score;
        if (high == null || score > high) high = score;
        if (low == null || score < low) low = score;
        if (maxScore > 0 && score / maxScore >= passFraction) passed++;
      case MarkState.absent:
        absent++;
      case MarkState.missing:
        missing++;
      case MarkState.invalid:
        invalid++;
    }
  }
  return SheetStats(
    total: total,
    valid: valid,
    absent: absent,
    missing: missing,
    invalid: invalid,
    averagePercent: valid == 0 || maxScore <= 0
        ? null
        : _round1(sum / valid / maxScore * 100),
    highest: high,
    lowest: low,
    passRatePercent: valid == 0 ? null : (passed / valid * 100).round(),
  );
}

/// One valid mark with its class position.
class RankedMark {
  final int position;
  final String studentId;
  final String name;
  final double score;
  final double percent;
  final String grade;

  const RankedMark({
    required this.position,
    required this.studentId,
    required this.name,
    required this.score,
    required this.percent,
    required this.grade,
  });
}

/// Ranks valid marks best first. Equal scores share a position and the next
/// position skips ahead (1, 2, 2, 4), the usual class-position convention.
List<RankedMark> rankMarks(
  Iterable<({String studentId, String name, double score})> marks,
  double maxScore,
) {
  final sorted = marks.toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.name.compareTo(b.name);
    });
  final ranked = <RankedMark>[];
  for (var i = 0; i < sorted.length; i++) {
    final m = sorted[i];
    final position = i > 0 && m.score == sorted[i - 1].score
        ? ranked[i - 1].position
        : i + 1;
    final percent = maxScore > 0 ? m.score / maxScore * 100 : 0.0;
    ranked.add(
      RankedMark(
        position: position,
        studentId: m.studentId,
        name: m.name,
        score: m.score,
        percent: _round1(percent),
        grade: gradeLetter(percent),
      ),
    );
  }
  return ranked;
}

/// Counts of valid scores in ten percentage bands (0-9 ... 90-100).
List<int> markBands(Iterable<double> scores, double maxScore) {
  final bands = List<int>.filled(10, 0);
  if (maxScore <= 0) return bands;
  for (final score in scores) {
    final index = (score / maxScore * 10).floor().clamp(0, 9);
    bands[index]++;
  }
  return bands;
}

/// Where an assessment is in its life.
enum SheetLifecycle { draft, submitted, published }

/// Lifecycle of an assessment from the flags on its grade rows.
///
/// Published when every row is published; submitted when every row is
/// submitted (but not all published); otherwise draft. Having no rows is draft.
SheetLifecycle lifecycleOf(
  Iterable<({bool submitted, bool published})> grades,
) {
  var count = 0, submitted = 0, published = 0;
  for (final g in grades) {
    count++;
    if (g.published) published++;
    if (g.submitted || g.published) submitted++;
  }
  if (count == 0) return SheetLifecycle.draft;
  if (published == count) return SheetLifecycle.published;
  if (submitted == count) return SheetLifecycle.submitted;
  return SheetLifecycle.draft;
}
