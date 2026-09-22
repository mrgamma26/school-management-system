import '../../../core/database/supabase_client.dart';
import '../domain/student.dart';

/// Data access layer for the [student], [studentguardian] and
/// [studentclasshistory] tables.
class StudentRepository {
  /// Returns all students ordered by last name.
  Future<List<Student>> listStudents() async {
    final rows = await supabase.from('student').select().order('lastname');
    return rows.map((r) => Student.fromJson(r)).toList();
  }

  /// Returns a single student by [studentId].
  Future<Student> getStudent(String studentId) async {
    final row = await supabase
        .from('student')
        .select()
        .eq('studentid', studentId)
        .single();
    return Student.fromJson(row);
  }

  /// Inserts a new student record.
  Future<String> createStudent(Map<String, dynamic> data) async {
    final row = await supabase
        .from('student')
        .insert(data)
        .select('studentid')
        .single();
    return row['studentid'] as String;
  }

  /// Updates permitted fields on an existing student.
  Future<void> updateStudent(
    String studentId,
    Map<String, dynamic> data,
  ) async {
    await supabase.from('student').update(data).eq('studentid', studentId);
  }

  /// Sets the [enrollmentstatus] field.
  Future<void> setEnrollmentStatus(String studentId, String status) async {
    await supabase
        .from('student')
        .update({'enrollmentstatus': status})
        .eq('studentid', studentId);
  }

  // Guardian links

  /// Returns all guardians linked to [studentId].
  Future<List<Map<String, dynamic>>> getLinkedGuardians(
    String studentId,
  ) async {
    return await supabase
        .from('studentguardian')
        .select('*, guardian(*)')
        .eq('studentid', studentId);
  }

  /// Links a guardian to a student via [studentguardian].
  Future<void> linkGuardian({
    required String studentId,
    required String guardianId,
    required String relationship,
  }) async {
    await supabase.from('studentguardian').insert({
      'studentid': studentId,
      'guardianid': guardianId,
      'relationship': relationship,
    });
  }

  /// Removes the link between a student and guardian.
  Future<void> unlinkGuardian({
    required String studentId,
    required String guardianId,
  }) async {
    await supabase.from('studentguardian').delete().match({
      'studentid': studentId,
      'guardianid': guardianId,
    });
  }

  // Class history

  /// Returns class-history rows for [studentId] joined with class and
  /// academic year data.
  Future<List<Map<String, dynamic>>> getClassHistory(String studentId) async {
    return await supabase
        .from('studentclasshistory')
        .select('*, class(*), academicyear(*)')
        .eq('studentid', studentId)
        .order('enrollmentdate', ascending: false);
  }

  /// Closes any open placement (enddate IS NULL) and inserts a new one.
  /// This is the safe class-assignment method.
  Future<void> assignClass({
    required String studentId,
    required String classId,
    required String academicYearId,
    required DateTime enrollmentDate,
  }) async {
    // Close the existing open placement first (via database function)
    await supabase.rpc(
      'close_current_class_placement',
      params: {'student_id': studentId},
    );

    // Insert the new placement
    await supabase.from('studentclasshistory').insert({
      'studentid': studentId,
      'classid': classId,
      'academicyearid': academicYearId,
      'enrollmentdate': enrollmentDate.toIso8601String().substring(0, 10),
    });
  }
}
