import '../../../core/database/supabase_client.dart';
import '../domain/mark_sheet.dart';
import 'mark_workspace_repository.dart';

String _personName(Object? row) {
  if (row is! Map) return '';
  final first = row['firstname']?.toString().trim() ?? '';
  final last = row['lastname']?.toString().trim() ?? '';
  return '$first $last'.trim();
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

/// A submitted assessment waiting for the Head Teacher: it has at least one
/// grade that is SUBMITTED but not yet published.
class ReviewQueueItem {
  final String assessmentId;
  final String classSubjectId;
  final String name;
  final String type;
  final double maxScore;
  final String className;
  final String subjectName;
  final String teacherName;
  final String periodLabel;

  /// Grades submitted and not yet published.
  final int awaitingGrades;
  final DateTime? lastSubmittedAt;

  const ReviewQueueItem({
    required this.assessmentId,
    required this.classSubjectId,
    required this.name,
    required this.type,
    required this.maxScore,
    required this.className,
    required this.subjectName,
    required this.teacherName,
    required this.periodLabel,
    required this.awaitingGrades,
    required this.lastSubmittedAt,
  });

  String get title => '$subjectName · $className';

  factory ReviewQueueItem.fromJson(Map<String, dynamic> j) {
    final cs = (j['classsubject'] as Map?) ?? const {};
    final period = cs['academicyear'] as Map?;
    final grades = (j['grade'] as List?) ?? const [];
    DateTime? last;
    for (final g in grades) {
      final at = _parseDate(g is Map ? g['updatedat'] : null);
      if (at != null && (last == null || at.isAfter(last))) last = at;
    }
    final year = (period?['academicyear'] as num?)?.toInt();
    final term = period?['term']?.toString().replaceAll('_', ' ') ?? '';
    return ReviewQueueItem(
      assessmentId: j['assessmentid'] as String,
      classSubjectId: (cs['classsubjectid'] ?? j['classsubjectid']) as String,
      name: j['assessmentname']?.toString() ?? '—',
      type: j['assessmenttype']?.toString() ?? '—',
      maxScore: (j['maxscore'] as num?)?.toDouble() ?? 0,
      className: (cs['class'] as Map?)?['classroomname']?.toString() ?? '—',
      subjectName: (cs['subject'] as Map?)?['subjectname']?.toString() ?? '—',
      teacherName: _personName(cs['staff']),
      periodLabel: year == null
          ? ''
          : '$year/${year + 1}${term.isEmpty ? '' : ' • $term'}',
      awaitingGrades: grades.length,
      lastSubmittedAt: last,
    );
  }
}

/// Everything the review panel shows for one submitted assessment.
class ReviewDetail {
  final ReviewQueueItem item;
  final List<RosterStudent> roster;
  final List<SavedGrade> grades;
  final int pendingCorrections;

  const ReviewDetail({
    required this.item,
    required this.roster,
    required this.grades,
    required this.pendingCorrections,
  });

  Map<String, SavedGrade> get gradeByStudent => {
    for (final g in grades) g.studentId: g,
  };

  /// One reading per rostered student; a student with no grade row is missing.
  List<({RosterStudent student, MarkCheck check})> get checks {
    final byStudent = gradeByStudent;
    return [
      for (final s in roster)
        (
          student: s,
          check: byStudent[s.studentId] == null
              ? const MarkCheck(MarkState.missing)
              : checkStoredMark(
                  score: byStudent[s.studentId]!.score,
                  status: byStudent[s.studentId]!.status,
                  maxScore: item.maxScore,
                ),
        ),
    ];
  }

  SheetStats get stats =>
      computeSheetStats(checks.map((c) => c.check), item.maxScore);

  /// Names of students with no mark and no absence recorded.
  List<String> get missingNames => [
    for (final c in checks)
      if (c.check.state == MarkState.missing) c.student.name,
  ];

  /// Names of students whose stored mark is outside 0..max.
  List<String> get invalidNames => [
    for (final c in checks)
      if (c.check.state == MarkState.invalid) c.student.name,
  ];

  List<double> get validScores => [
    for (final c in checks)
      if (c.check.isValid) c.check.score!,
  ];

  /// Staff who entered marks on this sheet, by name.
  List<String> get authors {
    final names = <String>{
      for (final g in grades)
        if (g.enteredByName.isNotEmpty) g.enteredByName,
    };
    return names.toList()..sort();
  }

  DateTime? get firstEntered {
    DateTime? first;
    for (final g in grades) {
      final at = g.createdAt;
      if (at != null && (first == null || at.isBefore(first))) first = at;
    }
    return first;
  }

  DateTime? get lastChanged {
    DateTime? last;
    for (final g in grades) {
      final at = g.updatedAt;
      if (at != null && (last == null || at.isAfter(last))) last = at;
    }
    return last;
  }

  int get awaitingCount =>
      grades.where((g) => g.submitted && !g.published).length;
}

/// Reads for the Head Teacher review workspace. Decisions go through
/// `GradeRepository.publishAssessment` (RPC `publish_assessment_results`).
class ReviewWorkspaceRepository {
  static const _queueSelect =
      'assessmentid, assessmentname, assessmenttype, maxscore, createdat, '
      'classsubject(classsubjectid, class(classroomname), '
      'subject(subjectname), staff(firstname, lastname), '
      'academicyear(academicyear, term)), '
      'grade!inner(gradeid, updatedat)';

  /// Assessments that have submitted, unpublished grades, newest first.
  Future<List<ReviewQueueItem>> queue() async {
    final rows = await supabase
        .from('assessment')
        .select(_queueSelect)
        .eq('grade.submissionstatus', 'SUBMITTED')
        .isFilter('grade.published_at', null)
        .order('createdat', ascending: false)
        .limit(500);
    return [
      for (final r in rows as List)
        ReviewQueueItem.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Roster, stored grades and pending correction count for [item].
  Future<ReviewDetail> detail(ReviewQueueItem item) async {
    final workspace = MarkWorkspaceRepository();
    final roster = await workspace.roster(item.classSubjectId);
    final grades = await workspace.grades(item.assessmentId);
    var pending = 0;
    try {
      final rows = await supabase
          .from('result_correction_requests')
          .select('correction_request_id, grade!inner(assessmentid)')
          .eq('status', 'PENDING')
          .eq('grade.assessmentid', item.assessmentId);
      pending = (rows as List).length;
    } catch (_) {
      // The correction count is context only; the review works without it.
    }
    return ReviewDetail(
      item: item,
      roster: roster,
      grades: grades,
      pendingCorrections: pending,
    );
  }
}
