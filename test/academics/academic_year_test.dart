import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/academics/domain/models/academic_year.dart';

void main() {
  test('academic-year span is independent of its legacy reporting term', () {
    for (final term in ['TERM_1', 'TERM_2', 'TERM_3', 'TERM_4']) {
      final year = AcademicYear(
        id: 'year',
        year: 2026,
        term: term,
        form: 'FORM_2',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2027, 7),
      );
      expect(year.label, '2026/2027');
      expect(year.term, term);
      expect(year.form, 'FORM_2');
    }
  });

  test(
    'numeric and string year values use the same consecutive-year label',
    () {
      expect(formatAcademicYear(2026), '2026/2027');
      expect(formatAcademicYear('2027'), '2027/2028');
      expect(formatAcademicYear(2099), '2099/2100');
    },
  );

  test('form and term codes have readable labels', () {
    expect(formatFormLevel('FORM_1'), 'Form 1');
    expect(formatFormLevel('FORM_4'), 'Form 4');
    expect(formatFormLevel(null), 'Form not configured');
    expect(formatAcademicTerm('TERM_1'), 'Term 1');
    expect(formatAcademicTerm('TERM_3'), 'Term 3');
    expect(formatAcademicTerm(null), 'Term not configured');
  });

  test('selection label distinguishes year, term and form', () {
    final period = AcademicYear(
      id: 'period',
      year: 2026,
      term: 'TERM_2',
      form: 'FORM_3',
      startDate: DateTime(2027, 1),
      endDate: DateTime(2027, 4),
    );

    expect(period.selectionLabel, '2026/2027 · Term 2 · Form 3');
  });
}
