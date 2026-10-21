import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/academics/domain/models/academic_calendar.dart';

void main() {
  final yearStart = DateTime(2026, 1, 5);
  final yearEnd = DateTime(2026, 12, 4);

  List<AcademicTermDraft> validTerms() => [
    AcademicTermDraft(
      'TERM_1',
      startDate: DateTime(2026, 1, 5),
      endDate: DateTime(2026, 4, 3),
    ),
    AcademicTermDraft(
      'TERM_2',
      startDate: DateTime(2026, 4, 20),
      endDate: DateTime(2026, 7, 31),
    ),
    AcademicTermDraft(
      'TERM_3',
      startDate: DateTime(2026, 8, 17),
      endDate: DateTime(2026, 12, 4),
    ),
  ];

  test('canonical academic-year names collapse equivalent input', () {
    expect(canonicalAcademicYearName('2026'), '2026/2027');
    expect(canonicalAcademicYearName(' 2026 / 2027 '), '2026/2027');
    expect(canonicalAcademicYearName('2026/2028'), isNull);
  });

  test('accepts one school year containing three ordered terms', () {
    expect(
      validateAcademicCalendarDraft(
        yearStart: yearStart,
        yearEnd: yearEnd,
        terms: validTerms(),
      ),
      isNull,
    );
  });

  test('requires all three reusable term definitions', () {
    final terms = validTerms()..removeLast();
    expect(
      validateAcademicCalendarDraft(
        yearStart: yearStart,
        yearEnd: yearEnd,
        terms: terms,
      ),
      contains('all required'),
    );
  });

  test('rejects a term outside the academic year', () {
    final terms = validTerms();
    terms.first.startDate = DateTime(2025, 12, 1);
    expect(
      validateAcademicCalendarDraft(
        yearStart: yearStart,
        yearEnd: yearEnd,
        terms: terms,
      ),
      contains('inside'),
    );
  });

  test('rejects overlapping term ranges', () {
    final terms = validTerms();
    terms[1].startDate = terms.first.endDate;
    expect(
      validateAcademicCalendarDraft(
        yearStart: yearStart,
        yearEnd: yearEnd,
        terms: terms,
      ),
      contains('must start after'),
    );
  });

  group('academic year input', () {
    test('accepts a starting year and a consecutive-year label', () {
      expect(parseAcademicStartYear('2027'), 2027);
      expect(parseAcademicStartYear('2027/2028'), 2027);
    });

    test('rejects malformed and non-consecutive labels', () {
      expect(parseAcademicStartYear('school year 2027'), isNull);
      expect(parseAcademicStartYear('2027/2029'), isNull);
    });

    test('rejects calendar dates before the entered starting year', () {
      expect(
        validateAcademicCalendarDraft(
          academicStartYear: 2027,
          yearStart: DateTime(2026, 12, 30),
          yearEnd: DateTime(2027, 12, 1),
          terms: [
            AcademicTermDraft(
              'TERM_1',
              startDate: DateTime(2027, 1, 2),
              endDate: DateTime(2027, 3, 1),
            ),
            AcademicTermDraft(
              'TERM_2',
              startDate: DateTime(2027, 4, 1),
              endDate: DateTime(2027, 7, 1),
            ),
            AcademicTermDraft(
              'TERM_3',
              startDate: DateTime(2027, 8, 1),
              endDate: DateTime(2027, 11, 1),
            ),
          ],
        ),
        contains('2027'),
      );
    });

    test('allows the academic year to end in the following year', () {
      expect(
        validateAcademicCalendarDraft(
          academicStartYear: 2027,
          yearStart: DateTime(2027, 9, 1),
          yearEnd: DateTime(2028, 7, 31),
          terms: [
            AcademicTermDraft(
              'TERM_1',
              startDate: DateTime(2027, 9, 1),
              endDate: DateTime(2027, 12, 1),
            ),
            AcademicTermDraft(
              'TERM_2',
              startDate: DateTime(2028, 1, 8),
              endDate: DateTime(2028, 3, 29),
            ),
            AcademicTermDraft(
              'TERM_3',
              startDate: DateTime(2028, 4, 15),
              endDate: DateTime(2028, 7, 31),
            ),
          ],
        ),
        isNull,
      );
    });
  });
}
