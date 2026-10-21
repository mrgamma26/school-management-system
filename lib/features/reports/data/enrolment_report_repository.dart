import '../../../core/database/supabase_client.dart';

class EnrolmentReportData {
  final int totalEnrolled;
  final int maleCount;
  final int femaleCount;
  final int activeInYear;
  final Map<String, int> byClass;

  const EnrolmentReportData({
    required this.totalEnrolled,
    required this.maleCount,
    required this.femaleCount,
    required this.activeInYear,
    required this.byClass,
  });

  factory EnrolmentReportData.fromRows(List<Map<String, dynamic>> rows) {
    final seenStudents = <String>{};
    final byClass = <String, int>{};
    var maleCount = 0;
    var femaleCount = 0;
    var activeInYear = 0;

    for (final row in rows) {
      final studentId = row['studentid']?.toString();
      if (studentId == null ||
          studentId.isEmpty ||
          !seenStudents.add(studentId)) {
        continue;
      }

      final classRow = row['class'] as Map?;
      final className = classRow?['classroomname']?.toString().trim();
      final label = className == null || className.isEmpty
          ? 'Unknown'
          : className;
      byClass[label] = (byClass[label] ?? 0) + 1;

      final student = row['student'] as Map?;
      switch (student?['gender']?.toString().toUpperCase()) {
        case 'MALE':
          maleCount++;
        case 'FEMALE':
          femaleCount++;
      }
      if (row['enddate'] == null) activeInYear++;
    }

    return EnrolmentReportData(
      totalEnrolled: seenStudents.length,
      maleCount: maleCount,
      femaleCount: femaleCount,
      activeInYear: activeInYear,
      byClass: Map.unmodifiable(byClass),
    );
  }
}

class EnrolmentReportRepository {
  const EnrolmentReportRepository();

  Future<EnrolmentReportData> load(String yearId) async {
    final response = await supabase
        .from('studentclasshistory')
        .select(
          'studentid, enddate, class(classroomname), student(gender, enrollmentstatus)',
        )
        .eq('academicyearid', yearId);
    return EnrolmentReportData.fromRows(
      List<Map<String, dynamic>>.from(response as List),
    );
  }
}
