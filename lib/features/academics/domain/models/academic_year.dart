/// Academic year record from the [academicyear] table.
class AcademicYear {
  final String id;
  final int year;
  final String term;
  final String? form;
  final DateTime startDate;
  final DateTime endDate;

  const AcademicYear({
    required this.id,
    required this.year,
    required this.term,
    this.form,
    required this.startDate,
    required this.endDate,
  });

  String get label => formatAcademicYear(year);

  /// Uniquely identifies a legacy period in selection controls.
  String get selectionLabel =>
      '$label · ${formatAcademicTerm(term)} · ${formatFormLevel(form)}';

  factory AcademicYear.fromJson(Map<String, dynamic> j) => AcademicYear(
    id: j['academicyearid'] as String,
    year: j['academicyear'] as int,
    term: j['term'].toString(),
    form: j['form']?.toString(),
    startDate: DateTime.parse(j['startdate'] as String),
    endDate: DateTime.parse(j['enddate'] as String),
  );

  @override
  String toString() => 'AcademicYear($id, $label)';
}

String formatAcademicTerm(Object? term) {
  return switch (term?.toString().toUpperCase()) {
    'TERM_1' => 'Term 1',
    'TERM_2' => 'Term 2',
    'TERM_3' => 'Term 3',
    'TERM_4' => 'Term 4',
    final value when value != null && value.isNotEmpty => value,
    _ => 'Term not configured',
  };
}

String formatFormLevel(String? form) {
  if (form == null || form.isEmpty) return 'Form not configured';
  return form
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

/// The academic session always spans two consecutive calendar years.
String formatAcademicYear(Object year) {
  final start = int.parse(year.toString());
  return '$start/${start + 1}';
}
