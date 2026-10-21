import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/assessments/domain/mark_sheet.dart';

void main() {
  group('gradeLetter', () {
    test('uses the report card scale', () {
      expect(gradeLetter(100), 'A');
      expect(gradeLetter(80), 'A');
      expect(gradeLetter(79.9), 'B');
      expect(gradeLetter(70), 'B');
      expect(gradeLetter(60), 'C');
      expect(gradeLetter(50), 'D');
      expect(gradeLetter(49.9), 'F');
      expect(gradeLetter(0), 'F');
    });
  });

  group('checkMark', () {
    test('empty text is missing, not invalid', () {
      expect(checkMark('', 100).state, MarkState.missing);
      expect(checkMark('   ', 100).state, MarkState.missing);
    });

    test('accepts scores from 0 to the maximum inclusive', () {
      expect(checkMark('0', 100).score, 0);
      expect(checkMark('100', 100).score, 100);
      expect(checkMark(' 55.5 ', 100).score, 55.5);
      expect(checkMark('55.5', 100).state, MarkState.valid);
    });

    test('flags non-numeric, negative and too-large entries', () {
      expect(checkMark('abc', 100).state, MarkState.invalid);
      expect(checkMark('-1', 100).state, MarkState.invalid);
      final high = checkMark('101', 100);
      expect(high.state, MarkState.invalid);
      expect(high.message, 'Enter 0 to 100.');
      expect(high.score, isNull);
      expect(checkMark('NaN', 100).state, MarkState.invalid);
      expect(checkMark('Infinity', 100).state, MarkState.invalid);
    });

    test('absent wins over typed text and carries no score', () {
      final check = checkMark('50', 100, absent: true);
      expect(check.state, MarkState.absent);
      expect(check.score, isNull);
    });
  });

  group('checkStoredMark', () {
    test('reads stored rows', () {
      expect(
        checkStoredMark(score: 70, status: 'PRESENT', maxScore: 100).state,
        MarkState.valid,
      );
      expect(
        checkStoredMark(score: null, status: 'MISSING', maxScore: 100).state,
        MarkState.missing,
      );
      expect(
        checkStoredMark(score: null, status: 'ABSENT', maxScore: 100).state,
        MarkState.absent,
      );
      expect(
        checkStoredMark(score: 120, status: 'PRESENT', maxScore: 100).state,
        MarkState.invalid,
      );
    });
  });

  test('formatScore drops useless decimals', () {
    expect(formatScore(74), '74');
    expect(formatScore(74.0), '74');
    expect(formatScore(55.5), '55.5');
    expect(formatScore(55.25), '55.25');
  });

  group('computeSheetStats', () {
    final checks = [
      checkMark('80', 100),
      checkMark('60', 100),
      checkMark('40', 100),
      checkMark('', 100),
      checkMark('x', 100),
      checkMark('', 100, absent: true),
    ];

    test('counts every state and the figures from valid marks only', () {
      final stats = computeSheetStats(checks, 100);
      expect(stats.total, 6);
      expect(stats.valid, 3);
      expect(stats.absent, 1);
      expect(stats.missing, 1);
      expect(stats.invalid, 1);
      expect(stats.accounted, 4);
      expect(stats.averagePercent, 60);
      expect(stats.highest, 80);
      expect(stats.lowest, 40);
      expect(stats.passRatePercent, 67);
      expect(stats.ready, isFalse);
    });

    test('is ready when nobody is missing or invalid; absent is fine', () {
      final stats = computeSheetStats([
        checkMark('90', 100),
        checkMark('', 100, absent: true),
      ], 100);
      expect(stats.ready, isTrue);
      expect(stats.completion, 1);
    });

    test('an empty roster is never ready and has no average', () {
      final stats = computeSheetStats(const [], 100);
      expect(stats.ready, isFalse);
      expect(stats.averagePercent, isNull);
      expect(stats.passRatePercent, isNull);
      expect(stats.completion, 0);
    });

    test('average is relative to the maximum and rounded to one decimal', () {
      final stats = computeSheetStats([
        checkMark('37', 50),
        checkMark('29', 50),
        checkMark('31', 50),
      ], 50);
      // (37 + 29 + 31) / 3 / 50 * 100 = 64.666...
      expect(stats.averagePercent, 64.7);
      expect(stats.passRatePercent, 100);
    });
  });

  group('rankMarks', () {
    test('orders best first and shares positions on ties', () {
      final ranked = rankMarks([
        (studentId: 'a', name: 'Ann', score: 70.0),
        (studentId: 'b', name: 'Ben', score: 90.0),
        (studentId: 'c', name: 'Cat', score: 70.0),
        (studentId: 'd', name: 'Dan', score: 40.0),
      ], 100);
      expect(ranked.map((r) => r.studentId), ['b', 'a', 'c', 'd']);
      expect(ranked.map((r) => r.position), [1, 2, 2, 4]);
      expect(ranked.map((r) => r.grade), ['A', 'B', 'B', 'F']);
      expect(ranked.first.percent, 90);
    });

    test('computes percent from the assessment maximum', () {
      final ranked = rankMarks([
        (studentId: 'a', name: 'Ann', score: 33.0),
      ], 50);
      expect(ranked.single.percent, 66);
      expect(ranked.single.grade, 'C');
    });
  });

  test('markBands puts scores into ten bands, 100 percent in the last', () {
    final bands = markBands([0, 9, 10, 55, 99, 100], 100);
    expect(bands, [2, 1, 0, 0, 0, 1, 0, 0, 0, 2]);
    expect(markBands([5], 0), List<int>.filled(10, 0));
  });

  group('lifecycleOf', () {
    test('no rows is a draft', () {
      expect(lifecycleOf(const []), SheetLifecycle.draft);
    });

    test('all published, all submitted, or mixed', () {
      expect(
        lifecycleOf([
          (submitted: true, published: true),
          (submitted: true, published: true),
        ]),
        SheetLifecycle.published,
      );
      expect(
        lifecycleOf([
          (submitted: true, published: false),
          (submitted: true, published: true),
        ]),
        SheetLifecycle.submitted,
      );
      expect(
        lifecycleOf([
          (submitted: false, published: false),
          (submitted: true, published: false),
        ]),
        SheetLifecycle.draft,
      );
    });

    test('a corrected row that went back to draft reopens the sheet', () {
      expect(
        lifecycleOf([
          (submitted: true, published: true),
          (submitted: false, published: false),
        ]),
        SheetLifecycle.draft,
      );
    });
  });
}
