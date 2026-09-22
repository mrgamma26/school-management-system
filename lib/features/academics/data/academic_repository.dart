import '../../../core/database/supabase_client.dart';
import '../domain/models/academic_year.dart';
import '../domain/models/class_model.dart';
import '../domain/models/subject.dart';
import '../domain/models/class_subject.dart';

/// Data access layer for academic structure tables.
class AcademicRepository {
  // ─────────────────────────────────────────────
  // Academic Years
  // ─────────────────────────────────────────────

  Future<List<AcademicYear>> listAcademicYears() async {
    final rows = await supabase
        .from('academicyear')
        .select('academicyearid, academicyear, termname, startdate, enddate')
        .order('academicyear', ascending: false);
    return rows.map((r) => AcademicYear.fromJson(r)).toList();
  }

  Future<void> createAcademicYear(Map<String, dynamic> data) async {
    await supabase.from('academicyear').insert(data);
  }

  Future<void> updateAcademicYear(String id, Map<String, dynamic> data) async {
    await supabase.from('academicyear').update(data).eq('academicyearid', id);
  }

  // ─────────────────────────────────────────────
  // Classes
  // ─────────────────────────────────────────────

  Future<List<ClassModel>> listClasses() async {
    final rows = await supabase
        .from('class')
        // DB uses `classroomname` and `form`, not `classname`/`formlevel`
        .select('classid, classroomname, form')
        .order('form');
    return rows.map((r) => ClassModel.fromJson(r)).toList();
  }

  Future<void> createClass(String classroomName, String? form) async {
    await supabase.from('class').insert({
      'classroomname': classroomName,
      'form': form,
    });
  }

  Future<void> updateClass(
    String classId,
    String classroomName,
    String? form,
  ) async {
    await supabase
        .from('class')
        .update({'classroomname': classroomName, 'form': form})
        .eq('classid', classId);
  }

  // ─────────────────────────────────────────────
  // Subjects
  // ─────────────────────────────────────────────

  Future<List<Subject>> listSubjects() async {
    final rows = await supabase
        .from('subject')
        .select('subjectid, subjectname, description')
        .order('subjectname');
    return rows.map((r) => Subject.fromJson(r)).toList();
  }

  Future<void> createSubject(String name, String? description) async {
    await supabase.from('subject').insert({
      'subjectname': name,
      'description': description,
    });
  }

  Future<void> updateSubject(
    String subjectId,
    String name,
    String? description,
  ) async {
    await supabase
        .from('subject')
        .update({'subjectname': name, 'description': description})
        .eq('subjectid', subjectId);
  }

  // ─────────────────────────────────────────────
  // Class-Subject Assignments (Teaching Assignments)
  // ─────────────────────────────────────────────

  /// Returns all teaching assignments for an academic year.
  Future<List<ClassSubject>> listAssignments(String academicYearId) async {
    final rows = await supabase
        .from('classsubject')
        .select('*, class(*), subject(*), staff(firstname, lastname)')
        .eq('academicyearid', academicYearId);
    return rows.map((r) => ClassSubject.fromJson(r)).toList();
  }

  /// Returns teaching assignments for a specific teacher in an academic year.
  Future<List<ClassSubject>> teacherAssignments(
    String staffId,
    String academicYearId,
  ) async {
    final rows = await supabase
        .from('classsubject')
        .select('*, class(*), subject(*)')
        .eq('staffid', staffId)
        .eq('academicyearid', academicYearId);
    return rows.map((r) => ClassSubject.fromJson(r)).toList();
  }

  /// Assigns a teacher to a class+subject for an academic year.
  Future<void> assignTeacher({
    required String classId,
    required String subjectId,
    required String staffId,
    required String academicYearId,
  }) async {
    await supabase.from('classsubject').insert({
      'classid': classId,
      'subjectid': subjectId,
      'staffid': staffId,
      'academicyearid': academicYearId,
    });
  }

  /// Removes a teaching assignment.
  Future<void> removeAssignment(String classSubjectId) async {
    await supabase
        .from('classsubject')
        .delete()
        .eq('classsubjectid', classSubjectId);
  }
}
