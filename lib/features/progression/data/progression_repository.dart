import '../../../core/database/supabase_client.dart';

/// Valid values for [progressionreview.decision] (progression_decision_enum).
const List<String> kProgressionDecisions = ['PENDING', 'PROMOTED', 'RETAINED'];

/// Data access for the [progressionreview] table.
///
/// Progression workflow:
/// 1. A PENDING review is created with the calculated average score.
/// 2. Head Teacher reviews and sets PROMOTED or RETAINED.
/// 3. The decision triggers the corresponding class-placement change.
///
/// DB constraint: averagescore must be 0–100 and NOT NULL.
/// DB constraint: unique (studentid, academicyearid) — one review per student per year.
class ProgressionRepository {
  /// Returns all PENDING progression reviews for an academic year,
  /// joined with student data.
  Future<List<Map<String, dynamic>>> pendingReviews(
    String academicYearId,
  ) async {
    return await supabase
        .from('progressionreview')
        .select('*, student(*)')
        .eq('academicyearid', academicYearId)
        .eq('decision', 'PENDING')
        .order('createdat');
  }

  /// Returns all progression reviews for an academic year regardless of
  /// status, joined with student and approving staff.
  Future<List<Map<String, dynamic>>> allReviews(String academicYearId) async {
    return await supabase
        .from('progressionreview')
        .select('*, student(*), staff!approvedby(firstname, lastname)')
        .eq('academicyearid', academicYearId)
        .order('createdat');
  }

  /// Creates a PENDING progression review for a student.
  ///
  /// [averageScore] is required (0–100) per DB constraint.
  Future<void> createReview({
    required String studentId,
    required String academicYearId,
    required double averageScore,
  }) async {
    assert(
      averageScore >= 0 && averageScore <= 100,
      'averageScore must be between 0 and 100.',
    );
    await supabase.from('progressionreview').insert({
      'studentid': studentId,
      'academicyearid': academicYearId,
      'averagescore': averageScore,
      'decision': 'PENDING',
    });
  }

  /// Creates or refreshes a PENDING annual review from submitted results.
  /// The database, not Flutter, calculates all evidence and averages.
  Future<Map<String, dynamic>> refreshAnnualReview({
    required String studentId,
    required String academicYearId,
  }) async {
    final period = await supabase
        .from('academicyear')
        .select('academicyear, form')
        .eq('academicyearid', academicYearId)
        .single();
    final result = await supabase.rpc(
      'refresh_progression_review',
      params: {
        'p_student_id': studentId,
        'p_school_year': period['academicyear'],
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> decideAndPlace({
    required String reviewId,
    required String decision,
    required String targetAcademicPeriodId,
    required String reason,
  }) async {
    final result = await supabase.rpc(
      'decide_and_place_student',
      params: {
        'p_review_id': reviewId,
        'p_decision': decision,
        'p_target_period_id': targetAcademicPeriodId,
        'p_reason': reason,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<String> nextAcademicPeriod(String sourcePeriodId) async {
    final source = await supabase
        .from('academicyear')
        .select('academicyear')
        .eq('academicyearid', sourcePeriodId)
        .single();
    final sourceForm = source['form']?.toString();
    final nextForm = switch (sourceForm) {
      'FORM_1' => 'FORM_2',
      'FORM_2' => 'FORM_3',
      'FORM_3' => 'FORM_4',
      _ => null,
    };
    if (nextForm == null) {
      throw StateError('No next form is configured after $sourceForm.');
    }
    final row = await supabase
        .from('academicyear')
        .select('academicyearid')
        .eq('academicyear', (source['academicyear'] as int) + 1)
        .eq('term', 'TERM_1')
        .eq('form', nextForm)
        .single();
    return row['academicyearid'] as String;
  }

  /// Records the Head Teacher's decision on a review.
  ///
  /// [decision] must be one of [kProgressionDecisions]: PROMOTED or RETAINED.
  Future<void> decide({
    required String reviewId,
    required String staffId,
    required String decision,
  }) async {
    assert(
      kProgressionDecisions.contains(decision) && decision != 'PENDING',
      'Decision must be PROMOTED or RETAINED, got: $decision',
    );
    await supabase
        .from('progressionreview')
        .update({'approvedby': staffId, 'decision': decision})
        .eq('reviewid', reviewId);
  }
}
