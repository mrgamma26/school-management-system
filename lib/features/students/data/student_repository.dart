import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/student.dart';

/// Maximum rows returned by [listStudents] in a single fetch.
/// A school with more students than this should implement cursor pagination,
/// but 2 000 covers every realistic single-school deployment.
const int kStudentPageSize = 2000;

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

/// Data access layer for the [student], [studentguardian] and
/// [studentclasshistory] tables.
class StudentRepository {
  /// Returns up to [kStudentPageSize] students ordered by last name.
  ///
  /// Pass [offset] to fetch subsequent pages:
  /// ```dart
  /// final page2 = await repo.listStudents(offset: kStudentPageSize);
  /// ```
  Future<List<Student>> listStudents({int offset = 0}) async {
    try {
      final rows = await supabase
          .from('student')
          .select()
          .order('lastname')
          .range(offset, offset + kStudentPageSize - 1);
      return rows.map((r) => Student.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<List<Student>> listStudentsForClass({
    required String classId,
    required String academicYearId,
  }) async {
    try {
      final rows = await supabase
          .from('studentclasshistory')
          .select('student!inner(*)')
          .eq('classid', classId)
          .eq('academicyearid', academicYearId)
          .isFilter('enddate', null);
      return (rows as List)
          .map(
            (row) => Student.fromJson(row['student'] as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns a single student by [studentId].
  Future<Student> getStudent(String studentId) async {
    try {
      final row = await supabase
          .from('student')
          .select()
          .eq('studentid', studentId)
          .single();
      return Student.fromJson(row);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Inserts a new student record.
  Future<String> createStudent(Map<String, dynamic> data) async {
    try {
      final resolvedStatus = await Student.resolveEnrollmentStatus(
        data['enrollmentstatus']?.toString(),
      );
      final insertData = <String, dynamic>{
        ...Map<String, dynamic>.from(data),
        'enrollmentstatus': resolvedStatus,
      };

      final row = await supabase
          .from('student')
          .insert(insertData)
          .select('studentid')
          .single();
      return row['studentid'] as String;
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Updates permitted fields on an existing student.
  Future<void> updateStudent(
    String studentId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resolved = <String, dynamic>{...data};
      if (data.containsKey('enrollmentstatus')) {
        resolved['enrollmentstatus'] = await Student.resolveEnrollmentStatus(
          data['enrollmentstatus']?.toString(),
        );
      }
      await supabase
          .from('student')
          .update(resolved)
          .eq('studentid', studentId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Sets the [enrollmentstatus] field.
  Future<void> setEnrollmentStatus(String studentId, String status) async {
    try {
      await supabase
          .from('student')
          .update({
            'enrollmentstatus': await Student.resolveEnrollmentStatus(status),
          })
          .eq('studentid', studentId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  // Guardian links

  /// Returns all guardians linked to [studentId].
  Future<List<Map<String, dynamic>>> getLinkedGuardians(
    String studentId,
  ) async {
    try {
      return await supabase
          .from('studentguardian')
          .select('*, guardian(*)')
          .eq('studentid', studentId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Links a guardian to a student via [studentguardian].
  Future<void> linkGuardian({
    required String studentId,
    required String guardianId,
    required String relationship,
  }) async {
    try {
      await supabase.from('studentguardian').insert({
        'studentid': studentId,
        'guardianid': guardianId,
        'relationship': relationship,
      });
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Removes the link between a student and guardian.
  Future<void> unlinkGuardian({
    required String studentId,
    required String guardianId,
  }) async {
    try {
      await supabase.from('studentguardian').delete().match({
        'studentid': studentId,
        'guardianid': guardianId,
      });
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<List<Map<String, dynamic>>> getStudentSubjects(
    String studentId,
  ) async {
    try {
      return await supabase
          .from('studentsubject')
          .select(
            'studentsubjectid, classsubjectid, classsubject(subject(subjectname), class(classroomname), staff(firstname, lastname))',
          )
          .eq('studentid', studentId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<List<Map<String, dynamic>>> listSubjectAssignments() async {
    try {
      return await supabase
          .from('classsubject')
          .select(
            'classsubjectid, subject(subjectname), class(classroomname), staff(firstname, lastname)',
          )
          .order('createdat');
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> addStudentSubject({
    required String studentId,
    required String classSubjectId,
  }) async {
    try {
      await supabase.from('studentsubject').insert({
        'studentid': studentId,
        'classsubjectid': classSubjectId,
      });
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> removeStudentSubject(String studentSubjectId) async {
    try {
      await supabase
          .from('studentsubject')
          .delete()
          .eq('studentsubjectid', studentSubjectId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Enrols a student in every subject assigned to their class for the
  /// academic year. This is idempotent so a retried registration is safe.
  Future<void> enrolInClassSubjects({
    required String studentId,
    required String classId,
    required String academicYearId,
  }) async {
    try {
      final assignments = await supabase
          .from('classsubject')
          .select('classsubjectid')
          .eq('classid', classId)
          .eq('academicyearid', academicYearId);
      final rows = List<Map<String, dynamic>>.from(assignments as List);
      if (rows.isEmpty) return;

      await supabase
          .from('studentsubject')
          .upsert(
            [
              for (final assignment in rows)
                {
                  'studentid': studentId,
                  'classsubjectid': assignment['classsubjectid'],
                },
            ],
            onConflict: 'studentid,classsubjectid',
            ignoreDuplicates: true,
          );
    } catch (e) {
      throw _mapException(e);
    }
  }

  // Class history

  /// Returns class-history rows for [studentId] joined with class and
  /// academic year data.
  Future<List<Map<String, dynamic>>> getClassHistory(String studentId) async {
    try {
      return await supabase
          .from('studentclasshistory')
          .select('*, class(*), academicyear(*)')
          .eq('studentid', studentId)
          .order('enrollmentdate', ascending: false);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Closes any open placement (enddate IS NULL) and inserts a new one.
  /// This is the safe class-assignment method.
  Future<void> assignClass({
    required String studentId,
    required String classId,
    required String academicYearId,
    required DateTime enrollmentDate,
  }) async {
    try {
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
    } catch (e) {
      throw _mapException(e);
    }
  }
}
