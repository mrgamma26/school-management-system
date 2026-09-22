/// Teaching assignment record from the [classsubject] table.
class ClassSubject {
  final String id;
  final String classId;
  final String subjectId;
  final String staffId;
  final String academicYearId;

  // Optional joined data
  final String? className;
  final String? subjectName;
  final String? staffName;

  const ClassSubject({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.staffId,
    required this.academicYearId,
    this.className,
    this.subjectName,
    this.staffName,
  });

  factory ClassSubject.fromJson(Map<String, dynamic> j) {
    final cls = j['class'] as Map<String, dynamic>?;
    final sub = j['subject'] as Map<String, dynamic>?;
    final staff = j['staff'] as Map<String, dynamic>?;

    return ClassSubject(
      id: j['classsubjectid'] as String,
      classId: j['classid'] as String,
      subjectId: j['subjectid'] as String,
      staffId: j['staffid'] as String,
      academicYearId: j['academicyearid'] as String,
      className: cls?['classroomname'] as String?,
      subjectName: sub?['subjectname'] as String?,
      staffName: staff != null
          ? '${staff['firstname']} ${staff['lastname']}'
          : null,
    );
  }

  @override
  String toString() => 'ClassSubject($id, $className/$subjectName)';
}
