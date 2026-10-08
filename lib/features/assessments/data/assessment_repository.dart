import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';

/// Maps Supabase/database errors to [AppException] subtypes.
AppException _mapException(Object error) {
  final text = error.toString();

  // Permission/auth errors → ForbiddenException
  if (text.contains('permission') ||
      text.contains('42501') ||
      text.contains('denied')) {
    return ForbiddenException(
      'You do not have permission to perform this action.',
    );
  }

  // Not found errors → NotFoundException
  if (text.contains('0 rows') ||
      text.contains('PGRST116') ||
      text.contains('single()') ||
      text.contains('no rows')) {
    return NotFoundException('Resource not found.');
  }

  // Network errors → NetworkException
  if (text.contains('network') ||
      text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset')) {
    return NetworkException(
      'Network error. Check your connection and try again.',
    );
  }

  // Server/database errors → ServerException
  return ServerException('Something went wrong. Please try again.');
}

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
  /// Throws [AppException] if maxScore is invalid or on any database/network error.
  Future<Assessment> createAssessment({
    required String classSubjectId,
    required String name,
    required String type,
    required double maxScore,
  }) async {
    if (maxScore <= 0) {
      throw ArgumentError('Max score must be greater than zero.');
    }
    try {
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
    } catch (e) {
      if (e is ArgumentError || e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Updates an existing assessment.
  /// Throws [AppException] on any database or network error.
  Future<void> updateAssessment(
    String assessmentId, {
    String? name,
    String? type,
    double? maxScore,
  }) async {
    if (maxScore != null && maxScore <= 0) {
      throw ArgumentError('Max score must be greater than zero.');
    }
    try {
      final data = <String, dynamic>{};
      if (name != null) data['assessmentname'] = name;
      if (type != null) data['assessmenttype'] = type;
      if (maxScore != null) data['maxscore'] = maxScore;
      await supabase
          .from('assessment')
          .update(data)
          .eq('assessmentid', assessmentId);
    } catch (e) {
      if (e is ArgumentError || e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Deletes an assessment (and cascades grades).
  /// Throws [AppException] on any database or network error.
  Future<void> deleteAssessment(String assessmentId) async {
    try {
      await supabase
          .from('assessment')
          .delete()
          .eq('assessmentid', assessmentId);
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }
}
