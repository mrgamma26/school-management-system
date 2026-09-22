/// Academic year record from the [academicyear] table.
class AcademicYear {
  final String id;
  final int year;
  final String term;
  final DateTime startDate;
  final DateTime endDate;

  const AcademicYear({
    required this.id,
    required this.year,
    required this.term,
    required this.startDate,
    required this.endDate,
  });

  String get label => '$year – $term';

  factory AcademicYear.fromJson(Map<String, dynamic> j) => AcademicYear(
    id: j['academicyearid'] as String,
    year: j['academicyear'] as int,
    // DB column is `termname` (term_enum), not `term`
    term: j['termname'].toString(),
    startDate: DateTime.parse(j['startdate'] as String),
    endDate: DateTime.parse(j['enddate'] as String),
  );

  @override
  String toString() => 'AcademicYear($id, $label)';
}
