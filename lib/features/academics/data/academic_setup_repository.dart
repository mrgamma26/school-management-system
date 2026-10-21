import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/rpc_error.dart';

class AcademicSetupRepository {
  Future<List<Map<String, dynamic>>> classes() async => _rows(
    supabase
        .from('class')
        .select('classid, classroomname, form')
        .order('form')
        .order('classroomname'),
  );

  Future<List<Map<String, dynamic>>> subjects() async => _rows(
    supabase
        .from('subject')
        .select('subjectid, subjectname')
        .order('subjectname'),
  );

  Future<List<Map<String, dynamic>>> configuredSubjects() async => _rows(
    supabase
        .from('class_subject_catalog')
        .select(
          'class_subject_id, class_id, subject_id, is_active, class:class_id(classroomname, form), subject:subject_id(subjectname)',
        )
        .eq('is_active', true)
        .order('created_at'),
  );

  Future<List<Map<String, dynamic>>> teachers() async {
    final rows = await supabase
        .from('staff')
        .select(
          'staffid, userid, firstname, middlename, lastname, systemuser!inner(isactive)',
        )
        .eq('systemuser.isactive', true);
    final roleRows = await supabase
        .from('user_roles')
        .select('user_id, role:role_id(rolename)');
    final teacherIds = <String>{
      for (final row in roleRows as List)
        if ({'TEACHER', 'HEAD_TEACHER'}.contains(
          ((row['role'] as Map<String, dynamic>?)?['rolename'] ?? '')
              .toString()
              .toUpperCase(),
        ))
          row['user_id'] as String,
    };
    return List<Map<String, dynamic>>.from(
      rows,
    ).where((row) => teacherIds.contains(row['userid'])).toList();
  }

  Future<List<Map<String, dynamic>>> assignments() async => _rows(
    supabase
        .from('teacher_assignments')
        .select(
          'teacher_assignment_id, status, assigned_at, academic_year:academic_year_id!inner(name, is_current), staff:staff_id(firstname, middlename, lastname), class_subject:class_subject_id(class:class_id(classroomname, form), subject:subject_id(subjectname))',
        )
        .eq('status', 'ACTIVE')
        .eq('academic_year.is_current', true)
        .order('assigned_at', ascending: false),
  );

  /// The current academic year row (`school_academic_years.is_current`), or
  /// null when the school has not set one yet. Used by the class-setup
  /// workspace so the year is automatic and never chosen by hand.
  Future<Map<String, dynamic>?> currentAcademicYear() async {
    try {
      return await supabase
          .from('school_academic_years')
          .select('academic_year_id, name')
          .eq('is_current', true)
          .maybeSingle();
    } catch (error) {
      throw ServerException('Could not load the current academic year: $error');
    }
  }

  /// Active teacher assignments for the current academic year, keyed by the
  /// information the matrix needs (`class_subject_id`, `staff_id`, staff name).
  Future<List<Map<String, dynamic>>> currentYearAssignments() async => _rows(
    supabase
        .from('teacher_assignments')
        .select(
          'teacher_assignment_id, class_subject_id, staff_id, staff:staff_id(firstname, middlename, lastname), academic_year:academic_year_id!inner(is_current)',
        )
        .eq('status', 'ACTIVE')
        .eq('academic_year.is_current', true),
  );

  /// Which subjects each teacher is marked as teaching
  /// (`staff_subjects`: `staff_id`, `subject_id`).
  Future<List<Map<String, dynamic>>> staffSubjects() async =>
      _rows(supabase.from('staff_subjects').select('staff_id, subject_id'));

  Future<void> configureClassSubjects(
    String classId,
    Set<String> subjectIds,
  ) async {
    try {
      await supabase.rpc(
        'configure_class_subjects',
        params: {'p_class_id': classId, 'p_subject_ids': subjectIds.toList()},
      );
    } catch (error) {
      throw ServerException(rpcErrorMessage(error));
    }
  }

  Future<void> assignTeacher({
    required String staffId,
    required Set<String> classSubjectIds,
    String? replacementReason,
  }) async {
    try {
      await supabase.rpc(
        'assign_teacher_to_class_subjects',
        params: {
          'p_staff_id': staffId,
          'p_class_subject_ids': classSubjectIds.toList(),
          'p_replacement_reason': replacementReason?.trim().isEmpty == true
              ? null
              : replacementReason?.trim(),
        },
      );
    } catch (error) {
      throw ServerException(rpcErrorMessage(error));
    }
  }

  /// Ends the current teacher of a class subject. The subject stays linked
  /// and the old assignment is kept as history.
  Future<void> removeTeacher({
    required String classSubjectId,
    String? reason,
  }) async {
    try {
      await supabase.rpc(
        'end_teacher_assignment',
        params: {
          'p_class_subject_id': classSubjectId,
          'p_reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
        },
      );
    } catch (error) {
      throw ServerException(rpcErrorMessage(error));
    }
  }

  /// Removes a subject from a class. The database refuses once the subject
  /// has assessments or marks in that class.
  Future<void> unlinkClassSubject(String classSubjectId) async {
    try {
      await supabase.rpc(
        'unlink_class_subject',
        params: {'p_class_subject_id': classSubjectId},
      );
    } catch (error) {
      throw ServerException(rpcErrorMessage(error));
    }
  }

  Future<List<Map<String, dynamic>>> _rows(dynamic query) async {
    try {
      final rows = await query;
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw ServerException('Could not load academic setup: $error');
    }
  }
}
