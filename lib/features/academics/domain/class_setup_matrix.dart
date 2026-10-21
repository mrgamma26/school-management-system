// Pure helpers behind the Class Setup workspace: validation of the class
// stage, form-level labels and the subject-by-class teacher matrix.
//
// Everything here works on the plain rows returned by
// `AcademicSetupRepository`, so it can be tested without a backend.

const classFormLevels = <String>['FORM_1', 'FORM_2', 'FORM_3', 'FORM_4'];

/// "FORM_3" -> "Form 3". Unknown values are tidied but never invented.
String formLevelLabel(String? form) {
  if (form == null || form.isEmpty) return '';
  final parts = form.split('_');
  return parts
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

/// Joins first / middle / last name parts, skipping blanks.
String staffDisplayName(Map<String, dynamic>? row) {
  if (row == null) return '';
  return [row['firstname'], row['middlename'], row['lastname']]
      .where((part) => part != null && part.toString().trim().isNotEmpty)
      .map((part) => part.toString().trim())
      .join(' ');
}

/// The form level a class belongs to, read from the start of its name:
/// "Form 3C" -> `FORM_3`, "form 1" -> `FORM_1`. Null when the name does not
/// start with Form 1 to Form 4.
///
/// The database keeps `class.form` because calendars, fees and progression are
/// scoped by form, but nobody picks it by hand any more: it follows the name.
String? formFromClassName(String name) {
  final match = RegExp(
    r'^\s*form\s*([1-4])(?!\d)',
    caseSensitive: false,
  ).firstMatch(name);
  return match == null ? null : 'FORM_${match.group(1)}';
}

/// Validation for a new class name. Returns an error message or null.
///
/// [existing] are the other classes (name + id) used to refuse duplicates;
/// [editingClassId] is excluded so a class can keep its own name.
String? validateClassName({
  required String name,
  required Iterable<Map<String, dynamic>> existing,
  String? editingClassId,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Enter a class name, for example Form 3C.';
  if (trimmed.length > 80) return 'Class names can be at most 80 characters.';
  if (formFromClassName(trimmed) == null) {
    return 'Start the class name with Form 1, 2, 3 or 4, for example Form 2B.';
  }
  final lower = trimmed.toLowerCase();
  final clash = existing.any(
    (row) =>
        row['classid'] != editingClassId &&
        (row['classroomname'] ?? '').toString().trim().toLowerCase() == lower,
  );
  if (clash) return 'A class with this name already exists.';
  return null;
}

/// Validation for renaming a class. Same rules as a new name, plus: the new
/// name must stay in the class's current form. Students placed in the class,
/// its calendar and its fees all follow the form, so a rename may not move it.
String? validateClassRename({
  required String name,
  required String currentForm,
  required Iterable<Map<String, dynamic>> existing,
  required String editingClassId,
}) {
  final error = validateClassName(
    name: name,
    existing: existing,
    editingClassId: editingClassId,
  );
  if (error != null) return error;
  if (formFromClassName(name) != currentForm) {
    return 'A rename cannot move the class to another form. Keep the name starting with ${formLevelLabel(currentForm)}.';
  }
  return null;
}

/// Teachers marked as teaching [subjectId], by name.
///
/// [staffSubjects] are `staff_subjects` rows (`staff_id`, `subject_id`);
/// [teachers] are the teacher staff rows. [excludeStaffId] drops the current
/// teacher from a "change teacher" list.
List<Map<String, dynamic>> teachersForSubject({
  required String subjectId,
  required Iterable<Map<String, dynamic>> teachers,
  required Iterable<Map<String, dynamic>> staffSubjects,
  String? excludeStaffId,
}) {
  final marked = {
    for (final row in staffSubjects)
      if (row['subject_id'] == subjectId) row['staff_id'] as String,
  };
  return [
    for (final teacher in teachers)
      if (marked.contains(teacher['staffid']) &&
          teacher['staffid'] != excludeStaffId)
        teacher,
  ]..sort((a, b) => staffDisplayName(a).compareTo(staffDisplayName(b)));
}

/// Reason rule when a teacher is changed or removed. The reason is optional
/// for a first assignment but kept short and bounded when given.
String? validateReassignReason(String? reason) {
  if ((reason ?? '').trim().length > 200) {
    return 'Keep the reason under 200 characters.';
  }
  return null;
}

/// One offered class-subject combination in the matrix.
class MatrixCell {
  final String classSubjectId;
  final String classId;
  final String subjectId;
  final String? staffId;
  final String? teacherName;

  const MatrixCell({
    required this.classSubjectId,
    required this.classId,
    required this.subjectId,
    this.staffId,
    this.teacherName,
  });

  bool get isAssigned => staffId != null;
}

/// Subjects as rows, classes as columns, for the current academic year.
class ClassSetupMatrix {
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final Map<String, MatrixCell> _cells;

  const ClassSetupMatrix._(this.classes, this.subjects, this._cells);

  /// [configured] rows come from `class_subject_catalog`
  /// (`class_subject_id`, `class_id`, `subject_id`); [assignments] are the
  /// ACTIVE rows of the current year (`class_subject_id`, `staff_id`, `staff`).
  /// Only subjects offered by at least one class become rows.
  factory ClassSetupMatrix.build({
    required List<Map<String, dynamic>> classes,
    required List<Map<String, dynamic>> subjects,
    required List<Map<String, dynamic>> configured,
    required List<Map<String, dynamic>> assignments,
  }) {
    final byClassSubject = <String, Map<String, dynamic>>{
      for (final row in assignments)
        if (row['class_subject_id'] != null)
          row['class_subject_id'] as String: row,
    };
    final cells = <String, MatrixCell>{};
    final offeredSubjects = <String>{};
    for (final row in configured) {
      final classSubjectId = row['class_subject_id'] as String?;
      final classId = row['class_id'] as String?;
      final subjectId = row['subject_id'] as String?;
      if (classSubjectId == null || classId == null || subjectId == null) {
        continue;
      }
      final assignment = byClassSubject[classSubjectId];
      final staff = assignment?['staff'];
      cells['$classId|$subjectId'] = MatrixCell(
        classSubjectId: classSubjectId,
        classId: classId,
        subjectId: subjectId,
        staffId: assignment?['staff_id'] as String?,
        teacherName: assignment == null
            ? null
            : staffDisplayName(
                staff is Map ? Map<String, dynamic>.from(staff) : null,
              ),
      );
      offeredSubjects.add(subjectId);
    }
    return ClassSetupMatrix._(classes, [
      for (final subject in subjects)
        if (offeredSubjects.contains(subject['subjectid'])) subject,
    ], cells);
  }

  MatrixCell? cell(String classId, String subjectId) =>
      _cells['$classId|$subjectId'];

  int get assignedCount => _cells.values.where((c) => c.isAssigned).length;

  int get openCount => _cells.length - assignedCount;

  int assignedInClass(String classId) =>
      _cells.values.where((c) => c.classId == classId && c.isAssigned).length;

  int offeredInClass(String classId) =>
      _cells.values.where((c) => c.classId == classId).length;

  /// How many class subjects a teacher currently teaches.
  int loadOf(String staffId) =>
      _cells.values.where((c) => c.staffId == staffId).length;

  /// The subjects a class offers, in catalogue order.
  List<Map<String, dynamic>> subjectsOfClass(String classId) => [
    for (final subject in subjects)
      if (cell(classId, subject['subjectid'] as String) != null) subject,
  ];
}
