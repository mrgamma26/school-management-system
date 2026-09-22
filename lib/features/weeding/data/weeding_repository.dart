import '../../../core/database/supabase_client.dart';

/// Valid values for [weedingreview.decision] (weeding_decision_enum).
const List<String> kWeedingDecisions = ['PENDING', 'WEED_OUT', 'RETAIN'];

/// Data access for the [weedingreview] table.
///
/// Weeding workflow:
/// 1. A student with a poor cumulative average is flagged with PENDING status.
/// 2. Head Teacher decides: WEED_OUT (remove) or RETAIN (keep).
/// 3. A decision reason is always required.
///
/// DB constraint: cumulativeaverage must be 0-100.
/// DB constraint: unique (studentid, academicyearid) - one review per student per year.
/// DB constraint: decisiondate must be >= flaggeddate.
class WeedingRepository {
  /// Returns all PENDING weeding reviews for an academic year,
  /// joined with student data.
  Future<List<Map<String, dynamic>>> pendingReviews(
    String academicYearId,
  ) async {
    return await supabase
        .from('weedingreview')
        .select('*, student(*)')
        .eq('academicyearid', academicYearId)
        .eq('decision', 'PENDING')
        .order('flaggeddate');
  }

  /// Returns all weeding reviews for an academic year, joined with student
  /// and deciding staff data.
  Future<List<Map<String, dynamic>>> allReviews(String academicYearId) async {
    return await supabase
        .from('weedingreview')
        .select('*, student(*), staff!decidedby(firstname, lastname)')
        .eq('academicyearid', academicYearId)
        .order('flaggeddate');
  }

  /// Flags a student for weeding review.
  ///
  /// [cumulativeAverage] is required (0-100) per DB constraint.
  Future<void> flagStudent({
    required String studentId,
    required String academicYearId,
    required double cumulativeAverage,
  }) async {
    assert(
      cumulativeAverage >= 0 && cumulativeAverage <= 100,
      'cumulativeAverage must be between 0 and 100.',
    );
    await supabase.from('weedingreview').insert({
      'studentid': studentId,
      'academicyearid': academicYearId,
      'cumulativeaverage': cumulativeAverage,
      'decision': 'PENDING',
      'flaggeddate': DateTime.now().toIso8601String().substring(0, 10),
    });
  }

  /// Records the Head Teacher's decision on a weeding review.
  ///
  /// [decision] must be WEED_OUT or RETAIN (from [kWeedingDecisions]).
  /// [reason] is always required.
  Future<void> decide({
    required String weedingId,
    required String staffId,
    required String decision,
    required String reason,
  }) async {
    assert(
      kWeedingDecisions.contains(decision) && decision != 'PENDING',
      'Decision must be WEED_OUT or RETAIN, got: $decision',
    );
    if (reason.trim().isEmpty) {
      throw ArgumentError('A decision reason is required.');
    }
    await supabase
        .from('weedingreview')
        .update({
          'decidedby': staffId,
          'decision': decision,
          'decisionreason': reason.trim(),
          'decisiondate': DateTime.now().toIso8601String().substring(0, 10),
        })
        .eq('weedingid', weedingId);
  }
}
