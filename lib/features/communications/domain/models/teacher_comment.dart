/// Teacher comment row from the [teachercomment] table.
class TeacherComment {
  final String commentId;
  final String studentId;
  final String staffId;
  final String academicYearId;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional joined data
  final String? studentName;
  final String? staffName;
  final String? academicYearLabel;

  const TeacherComment({
    required this.commentId,
    required this.studentId,
    required this.staffId,
    required this.academicYearId,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    this.studentName,
    this.staffName,
    this.academicYearLabel,
  });

  factory TeacherComment.fromJson(Map<String, dynamic> j) {
    final student = j['student'] as Map<String, dynamic>?;
    final staff = j['staff'] as Map<String, dynamic>?;
    final yr = j['academicyear'] as Map<String, dynamic>?;
    return TeacherComment(
      commentId: j['commentid'] as String,
      studentId: j['studentid'] as String,
      staffId: j['staffid'] as String,
      academicYearId: j['academicyearid'] as String,
      comment: j['comment'] as String,
      createdAt: DateTime.parse(j['createdat'] as String),
      updatedAt: DateTime.parse(j['updatedat'] as String),
      studentName: student != null
          ? '${student['firstname']} ${student['lastname']}'
          : null,
      staffName: staff != null
          ? '${staff['firstname']} ${staff['lastname']}'
          : null,
      academicYearLabel: yr != null
          ? '${yr['academicyear']} – ${yr['termname']}'
          : null,
    );
  }

  @override
  String toString() => 'TeacherComment($commentId)';
}
