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
    final existing = await supabase
        .from('grade')
        .select('gradeid')
        .eq('assessmentid', assessmentId)
        .eq('studentid', studentId)
        .maybeSingle();

    final data = {
      'assessmentid': assessmentId,
      'studentid': studentId,
      'enteredby': staffId,
      'score': score,
      'gradestatus': status,
    };

    if (existing == null) {
      await supabase.from('grade').insert(data);
    } else {
      await supabase
          .from('grade')
          .update(data)
          .eq('gradeid', existing['gradeid']);
    }
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
