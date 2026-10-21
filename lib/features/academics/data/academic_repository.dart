import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/models/academic_year.dart';
import '../domain/models/class_model.dart';
import '../domain/models/subject.dart';
import '../domain/models/class_subject.dart';

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

AppException _mapAcademicYearSaveError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('23505') ||
      text.contains('duplicate') ||
      text.contains('unique')) {
    return const ValidationException(
      'This term already exists for the selected academic year and form.',
    );
  }
  if (text.contains('permission') ||
      text.contains('42501') ||
      text.contains('denied')) {
    return const ForbiddenException(
      'You do not have permission to create an academic year. Ask a Super User for access.',
    );
  }
  if (text.contains('network') ||
      text.contains('socketexception') ||
      text.contains('connection')) {
    return const NetworkException(
      'We could not save the academic year. Check your connection and try again.',
    );
  }
  if (text.contains('termname') || text.contains('column')) {
    return const ServerException(
      'Academic year setup needs an update. Ask a Super User to apply the latest database migration.',
    );
  }
  return const ServerException(
    'We could not save the academic year. Please try again.',
  );
}

class AcademicRepository {
  // ─────────────────────────────────────────────
  // Academic Years
  // ─────────────────────────────────────────────

  Future<List<AcademicYear>> listAcademicYears() async {
    try {
      final rows = await supabase
          .from('academicyear')
          .select(
            'academicyearid, academicyear, term, form, startdate, enddate',
          )
          .order('academicyear', ascending: false);
      return rows.map((r) => AcademicYear.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> createAcademicYear(Map<String, dynamic> data) async {
    try {
      await supabase.from('academicyear').insert(data);
    } catch (e) {
      throw _mapAcademicYearSaveError(e);
    }
  }

  Future<bool> hasOverlappingPeriod({
    required int year,
    required String form,
    required DateTime startDate,
    required DateTime endDate,
    String? excludingId,
  }) async {
    final rows = await supabase
        .from('academicyear')
        .select('academicyearid, startdate, enddate')
        .eq('academicyear', year)
        .eq('form', form);
    return rows.any((row) {
      if (row['academicyearid'] == excludingId) return false;
      final start = DateTime.parse(row['startdate'] as String);
      final end = DateTime.parse(row['enddate'] as String);
      return !endDate.isBefore(start) && !startDate.isAfter(end);
    });
  }

  Future<void> updateAcademicYear(String id, Map<String, dynamic> data) async {
    try {
      await supabase.from('academicyear').update(data).eq('academicyearid', id);
    } catch (e) {
      throw _mapAcademicYearSaveError(e);
    }
  }

  Future<void> deleteAcademicYear(String id) async {
    try {
      await supabase.from('academicyear').delete().eq('academicyearid', id);
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ─────────────────────────────────────────────
  // Classes
  // ─────────────────────────────────────────────

  Future<List<ClassModel>> listClasses() async {
    try {
      final rows = await supabase
          .from('class')
          // DB uses `classroomname` and `form`, not `classname`/`formlevel`
          .select('classid, classroomname, form')
          .order('form');
      return rows.map((r) => ClassModel.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> createClass(String classroomName, String form) async {
    try {
      await supabase.from('class').insert({
        'classroomname': classroomName,
        'form': form,
      });
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> updateClass(
    String classId,
    String classroomName,
    String form,
  ) async {
    try {
      await supabase
          .from('class')
          .update({'classroomname': classroomName, 'form': form})
          .eq('classid', classId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ─────────────────────────────────────────────
  // Subjects
  // ─────────────────────────────────────────────

  Future<List<Subject>> listSubjects() async {
    try {
      final rows = await supabase
          .from('subject')
          .select('subjectid, subjectname, description')
          .order('subjectname');
      return rows.map((r) => Subject.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> createSubject(String name, String? description) async {
    try {
      await supabase.from('subject').insert({
        'subjectname': name,
        'description': description,
      });
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> updateSubject(
    String subjectId,
    String name,
    String? description,
  ) async {
    try {
      await supabase
          .from('subject')
          .update({'subjectname': name, 'description': description})
          .eq('subjectid', subjectId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ─────────────────────────────────────────────
  // Class-Subject Assignments (Teaching Assignments)
  // ─────────────────────────────────────────────

  Future<void> deleteSubject(String subjectId) async {
    try {
      await supabase.from('subject').delete().eq('subjectid', subjectId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns all teaching assignments for an academic year.
  Future<List<ClassSubject>> listAssignments(String academicYearId) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await supabase
            .from('classsubject')
            .select(
              'classsubjectid, classid, subjectid, staffid, academicyearid',
            )
            .eq('academicyearid', academicYearId),
      );
      return await _hydrateAssignments(rows);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns teaching assignments for a specific teacher in an academic year.
  Future<List<ClassSubject>> teacherAssignments(
    String staffId,
    String academicYearId,
  ) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await supabase
            .from('classsubject')
            .select(
              'classsubjectid, classid, subjectid, staffid, academicyearid',
            )
            .eq('staffid', staffId)
            .eq('academicyearid', academicYearId),
      );
      return await _hydrateAssignments(rows, includeStaff: false);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns every class-subject assignment belonging to the signed-in teacher.
  /// The caller supplies the authenticated user ID, never a staff ID from the UI.
  Future<List<ClassSubject>> teacherAssignmentsForUser(String userId) async {
    try {
      final staffRow = await supabase
          .from('staff')
          .select('staffid')
          .eq('userid', userId)
          .maybeSingle();
      final staffId = staffRow?['staffid'] as String?;
      if (staffId == null) return const [];

      // Assessment, roster and class-history records still use the legacy
      // classsubject/academicyear identifiers. The database bridge keeps these
      // rows linked to the active canonical teacher assignment, so use them as
      // the application-facing identifiers and let RLS hide replaced rows.
      final legacyRows = List<Map<String, dynamic>>.from(
        await supabase
            .from('classsubject')
            .select(
              'classsubjectid, classid, subjectid, staffid, academicyearid',
            )
            .eq('staffid', staffId),
      );
      if (legacyRows.isNotEmpty) {
        return await _hydrateAssignments(legacyRows, includeStaff: false);
      }

      // Compatibility fallback for a database where the bridge migration has
      // not run yet. These rows are useful for assignment listings, but mark
      // entry remains unavailable until matching legacy rows are synchronized.
      final assignmentRows = List<Map<String, dynamic>>.from(
        await supabase
            .from('teacher_assignments')
            .select(
              'teacher_assignment_id, class_subject_id, academic_year_id, status, '
              'class_subject:class_subject_id(class_id, subject_id, '
              'class:class_id(classroomname), subject:subject_id(subjectname))',
            )
            .eq('staff_id', staffId)
            .eq('status', 'ACTIVE'),
      );
      return assignmentRows.map((row) {
        final classSubject =
            row['class_subject'] as Map<String, dynamic>? ?? {};
        final classRow = classSubject['class'] as Map<String, dynamic>? ?? {};
        final subjectRow =
            classSubject['subject'] as Map<String, dynamic>? ?? {};
        return ClassSubject(
          id: row['teacher_assignment_id'] as String,
          classId: classSubject['class_id'] as String,
          subjectId: classSubject['subject_id'] as String,
          staffId: staffId,
          academicYearId: row['academic_year_id'] as String,
          className: classRow['classroomname'] as String?,
          subjectName: subjectRow['subjectname'] as String?,
        );
      }).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<List<ClassSubject>> _hydrateAssignments(
    List<Map<String, dynamic>> rows, {
    bool includeStaff = true,
  }) async {
    try {
      if (rows.isEmpty) return const [];

      final classRows = List<Map<String, dynamic>>.from(
        await supabase.from('class').select('classid, classroomname'),
      );
      final subjectRows = List<Map<String, dynamic>>.from(
        await supabase.from('subject').select('subjectid, subjectname'),
      );
      final staffRows = includeStaff
          ? List<Map<String, dynamic>>.from(
              await supabase
                  .from('staff')
                  .select('staffid, firstname, lastname'),
            )
          : const <Map<String, dynamic>>[];

      final classes = {
        for (final row in classRows) row['classid'] as String: row,
      };
      final subjects = {
        for (final row in subjectRows) row['subjectid'] as String: row,
      };
      final staff = {
        for (final row in staffRows) row['staffid'] as String: row,
      };

      return rows
          .map(
            (row) => ClassSubject.fromJson({
              ...row,
              'class': classes[row['classid']],
              'subject': subjects[row['subjectid']],
              'staff': staff[row['staffid']],
            }),
          )
          .toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<List<Map<String, dynamic>>> currentAcademicYears() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await supabase
          .from('academicyear')
          .select(
            'academicyearid, academicyear, term, form, startdate, enddate',
          )
          .lte('startdate', today)
          .gte('enddate', today)
          .order('academicyear', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<List<Map<String, dynamic>>> teacherClasses({
    required String userId,
    required String academicYearId,
  }) async {
    try {
      final staffRow = await supabase
          .from('staff')
          .select('staffid')
          .eq('userid', userId)
          .maybeSingle();
      final staffId = staffRow?['staffid'] as String?;
      if (staffId == null) return const [];

      final rows = List<Map<String, dynamic>>.from(
        await supabase
            .from('classsubject')
            .select('classid')
            .eq('academicyearid', academicYearId)
            .eq('staffid', staffId),
      );

      final classRows = List<Map<String, dynamic>>.from(
        await supabase.from('class').select('classid, classroomname, form'),
      );
      final classById = {
        for (final row in classRows) row['classid'] as String: row,
      };
      final classes = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final classId = row['classid'] as String?;
        final classData = classId == null ? null : classById[classId];
        if (classData != null && classId != null) {
          classes[classId] = classData;
        }
      }
      return classes.values.toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Assigns a teacher to a class+subject for an academic year.
  Future<void> assignTeacher({
    required String classId,
    required String subjectId,
    required String staffId,
    required String academicYearId,
  }) async {
    try {
      await supabase.from('classsubject').insert({
        'classid': classId,
        'subjectid': subjectId,
        'staffid': staffId,
        'academicyearid': academicYearId,
      });
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Removes a teaching assignment.
  Future<void> removeAssignment(String classSubjectId) async {
    try {
      await supabase
          .from('classsubject')
          .delete()
          .eq('classsubjectid', classSubjectId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Updates the teacher for an existing assignment.
  Future<void> updateAssignment({
    required String assignmentId,
    required String newStaffId,
  }) async {
    try {
      await supabase
          .from('classsubject')
          .update({'staffid': newStaffId})
          .eq('classsubjectid', assignmentId);
    } catch (e) {
      throw _mapException(e);
    }
  }
}
