import '../../../core/database/supabase_client.dart';

String _personName(Object? row) {
  if (row is! Map) return '—';
  final first = row['firstname']?.toString().trim() ?? '';
  final last = row['lastname']?.toString().trim() ?? '';
  final full = '$first $last'.trim();
  return full.isEmpty ? '—' : full;
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

double? _parseNum(Object? value) => value is num ? value.toDouble() : null;

/// One row of `result_correction_requests`, with the names the screen needs.
class CorrectionRequestRow {
  final String id;
  final String gradeId;
  final String status;
  final String reason;
  final String? decisionReason;
  final double? oldScore;
  final double? newScore;
  final double? maxScore;
  final DateTime? requestedAt;
  final DateTime? decidedAt;
  final DateTime? completedAt;
  final String studentName;
  final String assessmentName;
  final String className;
  final String subjectName;
  final String requestedByName;
  final String approvedByName;

  const CorrectionRequestRow({
    required this.id,
    required this.gradeId,
    required this.status,
    required this.reason,
    required this.decisionReason,
    required this.oldScore,
    required this.newScore,
    required this.maxScore,
    required this.requestedAt,
    required this.decidedAt,
    required this.completedAt,
    required this.studentName,
    required this.assessmentName,
    required this.className,
    required this.subjectName,
    required this.requestedByName,
    required this.approvedByName,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';

  factory CorrectionRequestRow.fromJson(Map<String, dynamic> j) {
    final grade = j['grade'] as Map?;
    final assessment = grade?['assessment'] as Map?;
    final classSubject = assessment?['classsubject'] as Map?;
    return CorrectionRequestRow(
      id: j['correction_request_id'] as String,
      gradeId: j['grade_id'] as String,
      status: j['status'] as String,
      reason: j['reason'] as String? ?? '',
      decisionReason: j['decision_reason'] as String?,
      oldScore: _parseNum(j['old_score']),
      newScore: _parseNum(j['new_score']),
      maxScore: _parseNum(assessment?['maxscore']),
      requestedAt: _parseDate(j['requested_at']),
      decidedAt: _parseDate(j['decided_at']),
      completedAt: _parseDate(j['completed_at']),
      studentName: _personName(grade?['student']),
      assessmentName: assessment?['assessmentname']?.toString() ?? '—',
      className:
          (classSubject?['class'] as Map?)?['classroomname']?.toString() ?? '—',
      subjectName:
          (classSubject?['subject'] as Map?)?['subjectname']?.toString() ?? '—',
      requestedByName: _personName(j['requester']),
      approvedByName: _personName(j['approver']),
    );
  }
}

/// One assessment with how many of its grades are published.
class PublishableAssessment {
  final String id;
  final String name;
  final String type;
  final double maxScore;
  final String className;
  final String subjectName;
  final int totalGrades;
  final int publishedGrades;

  const PublishableAssessment({
    required this.id,
    required this.name,
    required this.type,
    required this.maxScore,
    required this.className,
    required this.subjectName,
    required this.totalGrades,
    required this.publishedGrades,
  });

  int get unpublishedGrades => totalGrades - publishedGrades;

  factory PublishableAssessment.fromJson(Map<String, dynamic> j) {
    final classSubject = j['classsubject'] as Map?;
    final grades = (j['grade'] as List?) ?? const [];
    return PublishableAssessment(
      id: j['assessmentid'] as String,
      name: j['assessmentname'] as String? ?? '—',
      type: j['assessmenttype']?.toString() ?? '—',
      maxScore: _parseNum(j['maxscore']) ?? 0,
      className:
          (classSubject?['class'] as Map?)?['classroomname']?.toString() ?? '—',
      subjectName:
          (classSubject?['subject'] as Map?)?['subjectname']?.toString() ?? '—',
      totalGrades: grades.length,
      publishedGrades: grades
          .where((g) => g is Map && g['published_at'] != null)
          .length,
    );
  }
}

/// Read side for the result-correction and result-publishing screens.
/// Writes go through the RPCs in [GradeRepository], never through the tables.
class ResultsReviewRepository {
  static const _correctionSelect =
      'correction_request_id, grade_id, reason, old_score, new_score, status, '
      'decision_reason, requested_at, decided_at, completed_at, '
      'requester:staff!requested_by(firstname, lastname), '
      'approver:staff!approved_by(firstname, lastname), '
      'grade(gradeid, student(firstname, lastname), '
      'assessment(assessmentname, maxscore, '
      'classsubject(class(classroomname), subject(subjectname))))';

  Future<List<CorrectionRequestRow>> listCorrectionRequests() async {
    final rows = await supabase
        .from('result_correction_requests')
        .select(_correctionSelect)
        .order('requested_at', ascending: false)
        .limit(1000);
    return [for (final r in rows) CorrectionRequestRow.fromJson(r)];
  }

  Future<List<PublishableAssessment>> listAssessmentsForPublishing() async {
    final rows = await supabase
        .from('assessment')
        .select(
          'assessmentid, assessmentname, assessmenttype, maxscore, createdat, '
          'classsubject(class(classroomname), subject(subjectname)), '
          'grade(gradeid, published_at)',
        )
        .order('createdat', ascending: false)
        .limit(1000);
    return [for (final r in rows) PublishableAssessment.fromJson(r)];
  }
}
