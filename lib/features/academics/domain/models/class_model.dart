/// Class record from the [class] table.
///
/// DB columns: classid, classroomname, form (form_enum: FORM_1..FORM_4)
/// Named [ClassModel] to avoid collision with Dart's built-in [Class].
class ClassModel {
  final String classId;

  /// Maps to the `classroomname` column (e.g. "Form 1A").
  final String className;

  /// Maps to the `form` enum column (e.g. "FORM_1"). Nullable for legacy rows.
  final String? form;

  const ClassModel({required this.classId, required this.className, this.form});

  /// Alias for classId (used in some UI code)
  String get id => classId;

  /// Alias for className (used in some UI code)
  String get classroomName => className;

  factory ClassModel.fromJson(Map<String, dynamic> j) => ClassModel(
    classId: j['classid'] as String,
    // DB uses `classroomname`, not `classname`
    className: j['classroomname'] as String,
    // DB uses `form` (form_enum), not `formlevel`
    form: j['form']?.toString(),
  );

  @override
  String toString() => 'ClassModel($classId, $className)';
}
