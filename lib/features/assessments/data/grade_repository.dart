import '../../../core/database/supabase_client.dart';

/// Grade model from the [grade] table.
class Grade {
  final String gradeId;
  final String assessmentId;
  final String studentId;
  final String enteredBy;
  final double? score;
  final String gradeStatus;

  const Grade({
    required this.gradeId,
    required this.assessmentId,
    required this.studentId,
    required this.enteredBy,
    this.score,
    required this.gradeStatus,
  });

  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
    gradeId: j['gradeid'] as String,
    assessmentId: j['assessmentid'] as String,
    studentId: j['studentid'] as String,
    enteredBy: j['enteredby'] as String,
    score: j['score'] != null ? (j['score'] as num).toDouble() : null,
    gradeStatus: j['gradestatus'].toString(),
  );
}

/// Validates that [raw] is a parseable numeric score not exceeding [maxScore].
/// Returns the parsed score, or null for an empty string.
/// Throws [FormatException] on invalid input.
double? validateScore(String raw, double maxScore) {
  if (raw.trim().isEmpty) return null;
  final score = double.tryParse(raw.trim());
  if (score == null) throw const FormatException('Score must be numeric.');
  if (score < 0) throw const FormatException('Score cannot be negative.');
  if (score > maxScore) {
    throw FormatException('Score cannot exceed the maximum of $maxScore.');
  }
  return score;
}

/// Data access for the [grade] table.
class GradeRepository {
  Future<int> publishAssessment(String assessmentId) async {
    final result = await supabase.rpc(
      'publish_assessment_results',
      params: {'p_assessment_id': assessmentId},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  /// Head Teacher / Super User: send a submitted, unpublished sheet back to
  /// the teacher as DRAFT with a reason (at least 10 characters). Returns the
  /// number of grades returned.
  Future<int> returnToTeacher({
    required String assessmentId,
    required String reason,
  }) async {
    final result = await supabase.rpc(
      'return_assessment_to_teacher',
      params: {'p_assessment_id': assessmentId, 'p_reason': reason},
    );
    final map = result is Map ? result : const {};
    return (map['grades_returned'] as num?)?.toInt() ?? 0;
  }

  Future<String> requestCorrection({
    required String gradeId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('A correction reason is required.');
    }
    final result = await supabase.rpc(
      'request_result_correction',
      params: {'p_grade_id': gradeId, 'p_reason': reason.trim()},
    );
    return result as String;
  }

  Future<void> decideCorrection({
    required String requestId,
    required bool approved,
    String? reason,
  }) async {
    await supabase.rpc(
      'decide_result_correction',
      params: {
        'p_request_id': requestId,
        'p_approved': approved,
        'p_reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      },
    );
  }

  Future<void> completeCorrection({
    required String requestId,
    required double? score,
  }) async {
    await supabase.rpc(
      'complete_result_correction',
      params: {'p_request_id': requestId, 'p_new_score': score},
    );
  }

  /// Returns all grades for a given [assessmentId].
  Future<List<Grade>> gradesForAssessment(String assessmentId) async {
    final rows = await supabase
        .from('grade')
        .select()
        .eq('assessmentid', assessmentId);
    return rows.map((r) => Grade.fromJson(r)).toList();
  }

  /// Upserts (insert-or-update) a grade row.
  ///
  /// [score] may be null when the status is ABSENT or MISSING.
  Future<void> saveGrade({
    required String assessmentId,
    required String studentId,
    required String staffId,
    required double? score,
    required String status,
  }) async {
    final data = {
      'assessmentid': assessmentId,
      'studentid': studentId,
      'enteredby': staffId,
      'score': score,
      'gradestatus': status,
      'submissionstatus': 'DRAFT',
    };

    // Atomic upsert prevents duplicate-key errors when auto-save and a quick
    // second edit overlap for the same assessment/student pair.
    await supabase.from('grade').upsert(
      data,
      onConflict: 'assessmentid,studentid',
    );
  }

  /// Makes all grades in an assessment eligible for annual progression.
  Future<void> submitAssessment(String assessmentId) async {
    await supabase
        .from('grade')
        .update({'submissionstatus': 'SUBMITTED'})
        .eq('assessmentid', assessmentId);
  }

  /// Returns the raw grade row for audit/correction purposes.
  Future<Map<String, dynamic>?> getRawGrade(
    String assessmentId,
    String studentId,
  ) async {
    return await supabase
        .from('grade')
        .select()
        .eq('assessmentid', assessmentId)
        .eq('studentid', studentId)
        .maybeSingle();
  }
}
