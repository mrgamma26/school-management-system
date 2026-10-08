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

  test('form codes have readable labels and legacy rows are explicit', () {
    expect(formatFormLevel('FORM_1'), 'Form 1');
    expect(formatFormLevel('FORM_4'), 'Form 4');
    expect(formatFormLevel(null), 'Form not configured');
  });
}
