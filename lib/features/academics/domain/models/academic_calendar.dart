class AcademicTermPeriod {
  final String id;
  final String code;
  final String name;
  final int sequence;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;

  const AcademicTermPeriod({
    required this.id,
    required this.code,
    required this.name,
    required this.sequence,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
  });

  factory AcademicTermPeriod.fromJson(Map<String, dynamic> json) {
    final definition = json['term_definitions'] as Map<String, dynamic>;
    return AcademicTermPeriod(
      id: json['academic_year_term_id'] as String,
      code: definition['code'] as String,
      name: definition['name'] as String,
      sequence: definition['sequence'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }
}

class AcademicCalendarYear {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final bool isCurrent;
  final List<AcademicTermPeriod> terms;

  const AcademicCalendarYear({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.isCurrent,
    required this.terms,
  });

  factory AcademicCalendarYear.fromJson(Map<String, dynamic> json) {
    final terms =
        List<Map<String, dynamic>>.from(
            json['academic_year_terms'] as List? ?? const [],
          ).map(AcademicTermPeriod.fromJson).toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return AcademicCalendarYear(
      id: json['academic_year_id'] as String,
      name: json['name'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: json['status'] as String,
      isCurrent: json['is_current'] as bool? ?? false,
      terms: terms,
    );
  }
}

class AcademicTermDraft {
  final String code;
  DateTime? startDate;
  DateTime? endDate;

  AcademicTermDraft(this.code, {this.startDate, this.endDate});

  String get label => switch (code) {
    'TERM_1' => 'Term 1',
    'TERM_2' => 'Term 2',
    _ => 'Term 3',
  };

  Map<String, dynamic> toJson() => {
    'code': code,
    'startDate': _date(startDate!),
    'endDate': _date(endDate!),
  };

  static String _date(DateTime value) =>
      value.toIso8601String().substring(0, 10);
}

/// Returns the starting year represented by either `YYYY` or `YYYY/YYYY+1`.
int? parseAcademicStartYear(String value) {
  final normalized = value.trim();
  final single = RegExp(r'^(\d{4})$').firstMatch(normalized);
  if (single != null) return int.parse(single.group(1)!);

  final span = RegExp(r'^(\d{4})\s*/\s*(\d{4})$').firstMatch(normalized);
  if (span == null) return null;
  final start = int.parse(span.group(1)!);
  final end = int.parse(span.group(2)!);
  return end == start + 1 ? start : null;
}

/// The single stored/displayed label for a valid academic year.
String? canonicalAcademicYearName(String value) {
  final start = parseAcademicStartYear(value);
  return start == null ? null : '$start/${start + 1}';
}

String? validateAcademicCalendarDraft({
  int? academicStartYear,
  required DateTime? yearStart,
  required DateTime? yearEnd,
  required List<AcademicTermDraft> terms,
}) {
  if (yearStart == null || yearEnd == null) {
    return 'Select the academic-year start and end dates.';
  }
  if (academicStartYear != null &&
      yearStart.isBefore(DateTime(academicStartYear))) {
    return 'Academic-year dates cannot start before $academicStartYear.';
  }
  if (!yearStart.isBefore(yearEnd)) {
    return 'The academic-year start date must be before its end date.';
  }
  if (terms.length != 3 ||
      terms.map((term) => term.code).toSet().length != 3 ||
      !const {
        'TERM_1',
        'TERM_2',
        'TERM_3',
      }.containsAll(terms.map((term) => term.code))) {
    return 'Term 1, Term 2, and Term 3 are all required.';
  }
  for (final term in terms) {
    if (term.startDate == null || term.endDate == null) {
      return '${term.label} requires both dates.';
    }
    if (!term.startDate!.isBefore(term.endDate!)) {
      return '${term.label} must start before it ends.';
    }
    if (term.startDate!.isBefore(yearStart) || term.endDate!.isAfter(yearEnd)) {
      return '${term.label} must be inside the academic year.';
    }
  }
  final ordered = [...terms]
    ..sort((left, right) => left.code.compareTo(right.code));
  for (var index = 1; index < ordered.length; index++) {
    if (!ordered[index].startDate!.isAfter(ordered[index - 1].endDate!)) {
      return '${ordered[index].label} must start after ${ordered[index - 1].label} ends.';
    }
  }
  return null;
}
