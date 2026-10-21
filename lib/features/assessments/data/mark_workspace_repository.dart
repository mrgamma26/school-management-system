import '../../../core/database/supabase_client.dart';
import 'assessment_repository.dart';

String _personName(Object? row) {
  if (row is! Map) return '';
  final first = row['firstname']?.toString().trim() ?? '';
  final last = row['lastname']?.toString().trim() ?? '';
  return '$first $last'.trim();
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

double? _parseNum(Object? value) => value is num ? value.toDouble() : null;

/// A class + subject the signed-in teacher is assigned to for one academic
/// period, as the "Enter marks" workspace offers it.
class TeacherAssignment {
  final String classSubjectId;
  final String className;
  final String subjectName;
  final int? academicYear;
  final String term;
  final DateTime? startDate;
  final DateTime? endDate;

  const TeacherAssignment({
    required this.classSubjectId,
    required this.className,
    required this.subjectName,
    required this.academicYear,
    required this.term,
    required this.startDate,
    required this.endDate,
  });

  /// "2026/2027 - Term 2", or "Academic period" when the period is unknown.
  String get periodLabel {
    if (academicYear == null) return 'Academic period';
    final termText = term.replaceAll('_', ' ');
    return '$academicYear/${academicYear! + 1}'
        '${termText.isEmpty ? '' : ' • $termText'}';
  }

  String get label => '$subjectName · $className';

  /// True when [today] falls inside the academic period.
  bool isCurrent(DateTime today) {
    final start = startDate, end = endDate;
    if (start == null || end == null) return false;
    final day = DateTime(today.year, today.month, today.day);
    return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
        !day.isAfter(DateTime(end.year, end.month, end.day));
  }

  /// Builds an assignment from a `classsubject` row with embedded `class`,
  /// `subject` and `academicyear`. Returns null unless the class form and the
  /// academic-period form match (the same rule the page always applied:
  /// only form-specific periods are shown).
  static TeacherAssignment? fromRow(Map<String, dynamic> row) {
    final period = row['academicyear'] as Map?;
    final classroom = row['class'] as Map?;
    if (period == null || classroom == null) return null;
    final periodForm = period['form']?.toString();
    final classForm = classroom['form']?.toString();
    if (periodForm == null || periodForm != classForm) return null;
    return TeacherAssignment(
      classSubjectId: row['classsubjectid'] as String,
      className: classroom['classroomname']?.toString() ?? '—',
      subjectName: (row['subject'] as Map?)?['subjectname']?.toString() ?? '—',
      academicYear: (period['academicyear'] as num?)?.toInt(),
      term: period['term']?.toString() ?? '',
      startDate: _parseDate(period['startdate']),
      endDate: _parseDate(period['enddate']),
    );
  }

  /// Builds an assignment from the normalized academic setup tables.
  static TeacherAssignment? fromCanonicalRow(Map<String, dynamic> row) {
    final classSubject = row['class_subject'] as Map?;
    final classroom = classSubject?['class'] as Map?;
    final subject = classSubject?['subject'] as Map?;
    final year = row['academic_year'] as Map?;
    if (classSubject == null ||
        classroom == null ||
        subject == null ||
        year == null) {
      return null;
    }
    final name = year['name']?.toString() ?? '';
    final match = RegExp(r'^(\d{4})(?:/(\d{4}))?$').firstMatch(name);
    return TeacherAssignment(
      classSubjectId: row['class_subject_id'] as String,
      className: classroom['classroomname']?.toString() ?? '—',
      subjectName: subject['subjectname']?.toString() ?? '—',
      academicYear: match == null ? null : int.tryParse(match.group(1)!),
      term: '',
      startDate: _parseDate(year['start_date']),
      endDate: _parseDate(year['end_date']),
    );
  }
}

/// A student on a class roster.
class RosterStudent {
  final String studentId;
  final String firstName;
  final String lastName;

  const RosterStudent({
    required this.studentId,
    required this.firstName,
    required this.lastName,
  });

  String get name => '$firstName $lastName'.trim();
}

/// One stored `grade` row, with the flags the workspace needs.
class SavedGrade {
  final String? gradeId;
  final String studentId;
  final double? score;
  final String status;
  final bool submitted;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final String enteredBy;
  final String enteredByName;

  const SavedGrade({
    required this.gradeId,
    required this.studentId,
    required this.score,
    required this.status,
    required this.submitted,
    this.publishedAt,
    this.updatedAt,
    this.createdAt,
    this.enteredBy = '',
    this.enteredByName = '',
  });

  bool get published => publishedAt != null;

  factory SavedGrade.fromJson(Map<String, dynamic> j) => SavedGrade(
    gradeId: j['gradeid'] as String?,
    studentId: j['studentid'] as String,
    score: _parseNum(j['score']),
    status: j['gradestatus']?.toString() ?? 'PRESENT',
    submitted: j['submissionstatus']?.toString().toUpperCase() == 'SUBMITTED',
    publishedAt: _parseDate(j['published_at']),
    updatedAt: _parseDate(j['updatedat']),
    // grade has no createdat column; the first-entry time is enteredat.
    createdAt: _parseDate(j['enteredat'] ?? j['createdat']),
    enteredBy: j['enteredby']?.toString() ?? '',
    enteredByName: _personName(j['author']),
  );
}

/// Reads for the "Enter marks" workspace. Marks are written through
/// `GradeRepository.saveGrade` / `submitAssessment`, assessments through
/// `AssessmentRepository`.
class MarkWorkspaceRepository {
  /// Staff id of the signed-in user, or null when the account has no staff row.
  Future<String?> staffIdForUser(String userId) async {
    final row = await supabase
        .from('staff')
        .select('staffid')
        .eq('userid', userId)
        .maybeSingle();
    return row?['staffid'] as String?;
  }

  /// The teacher's class-subject assignments whose class form matches the
  /// academic period form. Current periods first, then the most recent.
  Future<List<TeacherAssignment>> assignments(String staffId) async {
    final rows = await supabase
        .from('classsubject')
        .select(
          'classsubjectid, class(classroomname, form), subject(subjectname), '
          'academicyear(academicyearid, academicyear, term, form, startdate, enddate)',
        )
        .eq('staffid', staffId);
    final today = DateTime.now();
    final list = [
      for (final row in rows as List)
        ?TeacherAssignment.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
    return _sortAssignments(list, today);
  }

  List<TeacherAssignment> _sortAssignments(
    List<TeacherAssignment> list,
    DateTime today,
  ) {
    list.sort((a, b) {
      final cur = (b.isCurrent(today) ? 1 : 0) - (a.isCurrent(today) ? 1 : 0);
      if (cur != 0) return cur;
      final byDate = (b.startDate ?? DateTime(1970)).compareTo(
        a.startDate ?? DateTime(1970),
      );
      return byDate != 0 ? byDate : a.label.compareTo(b.label);
    });
    return list;
  }

  Future<List<Assessment>> assessmentsFor(String classSubjectId) =>
      AssessmentRepository().listForClassSubject(classSubjectId);

  /// An assessment by id (deep links), or null when it does not exist or the
  /// signed-in user cannot read it.
  Future<Assessment?> assessmentById(String assessmentId) async {
    final row = await supabase
        .from('assessment')
        .select()
        .eq('assessmentid', assessmentId)
        .maybeSingle();
    return row == null ? null : Assessment.fromJson(row);
  }

  /// Students currently enrolled in the class of [classSubjectId] (active
  /// class history for the academic year). When the subject has explicit
  /// enrolments (`studentsubject`) the roster is limited to those students,
  /// because grades can only be written for them; with none readable, the
  /// whole class is returned.
  Future<List<RosterStudent>> roster(String classSubjectId) async {
    final cs = await supabase
        .from('classsubject')
        .select('classid, academicyearid')
        .eq('classsubjectid', classSubjectId)
        .single();
    final rows = await supabase
        .from('studentclasshistory')
        .select('student(studentid, firstname, lastname)')
        .eq('classid', cs['classid'] as String)
        .eq('academicyearid', cs['academicyearid'] as String)
        .isFilter('enddate', null);
    var students = <RosterStudent>[
      for (final r in rows as List)
        if (r['student'] is Map)
          RosterStudent(
            studentId: (r['student'] as Map)['studentid'] as String,
            firstName: (r['student'] as Map)['firstname']?.toString() ?? '',
            lastName: (r['student'] as Map)['lastname']?.toString() ?? '',
          ),
    ];
    final enrolled = await supabase
        .from('studentsubject')
        .select('studentid')
        .eq('classsubjectid', classSubjectId);
    final enrolledIds = {
      for (final r in enrolled as List) r['studentid'] as String,
    };
    if (enrolledIds.isNotEmpty) {
      students = [
        for (final s in students)
          if (enrolledIds.contains(s.studentId)) s,
      ];
    }
    students.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return students;
  }

  /// Every stored grade of the assessment.
  Future<List<SavedGrade>> grades(String assessmentId) async {
    final rows = await supabase
        .from('grade')
        .select(
          'gradeid, studentid, score, gradestatus, submissionstatus, '
          'published_at, enteredat, updatedat, enteredby, '
          'author:staff!enteredby(firstname, lastname)',
        )
        .eq('assessmentid', assessmentId);
    return [
      for (final r in rows as List)
        SavedGrade.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }
}
