import '../../../core/database/supabase_client.dart';

/// Assessment model loaded from the [assessment] table.
class Assessment {
  final String id;
  final String classSubjectId;
  final String name;
  final String type;
  final double maxScore;

  const Assessment({
    required this.id,
    required this.classSubjectId,
    required this.name,
    required this.type,
    required this.maxScore,
  });

  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
    id: j['assessmentid'] as String,
    classSubjectId: j['classsubjectid'] as String,
    name: j['assessmentname'] as String,
    type: j['assessmenttype'].toString(),
    maxScore: (j['maxscore'] as num).toDouble(),
  );

  @override
  String toString() => 'Assessment($id, $name)';
}

/// Data access for the [assessment] table.
class AssessmentRepository {
  /// Returns all assessments for a given [classSubjectId].
  Future<List<Assessment>> listForClassSubject(String classSubjectId) async {
    final rows = await supabase
        .from('assessment')
        .select()
        .eq('classsubjectid', classSubjectId)
        .order('createdat');
    return rows.map((r) => Assessment.fromJson(r)).toList();
  }

  /// Creates a new assessment.
  Future<Assessment> createAssessment({
    required String classSubjectId,
    required String name,
    required String type,
    required double maxScore,
  }) async {
    if (maxScore <= 0) {
      throw ArgumentError('Max score must be greater than zero.');
    }
    final row = await supabase
        .from('assessment')
        .insert({
          'classsubjectid': classSubjectId,
          'assessmentname': name,
          'assessmenttype': type,
          'maxscore': maxScore,
        })
        .select()
        .single();
    return Assessment.fromJson(row);
  }

  /// Updates an existing assessment.
  Future<void> updateAssessment(
    String assessmentId, {
    String? name,
    String? type,
    double? maxScore,
  }) async {
    if (maxScore != null && maxScore <= 0) {
      throw ArgumentError('Max score must be greater than zero.');
    }
    final data = <String, dynamic>{};
    if (name != null) data['assessmentname'] = name;
    if (type != null) data['assessmenttype'] = type;
    if (maxScore != null) data['maxscore'] = maxScore;
    await supabase
        .from('assessment')
        .update(data)
        .eq('assessmentid', assessmentId);
  }

  /// Deletes an assessment (and cascades grades).
  Future<void> deleteAssessment(String assessmentId) async {
    await supabase.from('assessment').delete().eq('assessmentid', assessmentId);
  }
}
