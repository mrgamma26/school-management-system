/// Subject record from the [subject] table.
class Subject {
  final String subjectId;
  final String subjectName;
  final String? description;

  const Subject({
    required this.subjectId,
    required this.subjectName,
    this.description,
  });

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    subjectId: j['subjectid'] as String,
    subjectName: j['subjectname'] as String,
    description: j['description'] as String?,
  );

  @override
  String toString() => 'Subject($subjectId, $subjectName)';
}
