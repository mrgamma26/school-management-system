import '../../../core/database/supabase_client.dart';

/// Student row from the [student] table.
class Student {
  static List<String>? _cachedStatuses;

  /// Fetches and caches the enum's actual valid labels from the database.
  static Future<List<String>> fetchValidEnrollmentStatuses() async {
    if (_cachedStatuses != null) return _cachedStatuses!;
    final result = await supabase.rpc('get_student_status_values');
    _cachedStatuses = (result as List).map((e) => e.toString()).toList();
    return _cachedStatuses!;
  }

  /// Matches [rawStatus] case-insensitively against the real database values.
  static Future<String> resolveEnrollmentStatus(String? rawStatus) async {
    final values = await fetchValidEnrollmentStatuses();
    final wanted = (rawStatus ?? 'enrolled').trim().toLowerCase();
    return values.firstWhere(
      (value) => value.toLowerCase() == wanted,
      orElse: () => values.first,
    );
  }

  final String studentId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final String? physicalAddress;
  final String enrollmentStatus;

  const Student({
    required this.studentId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    this.physicalAddress,
    required this.enrollmentStatus,
  });

  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((p) => p != null && p.isNotEmpty).join(' ');

  factory Student.fromJson(Map<String, dynamic> j) => Student(
    studentId: j['studentid'] as String,
    firstName: j['firstname'] as String,
    middleName: j['middlename'] as String?,
    lastName: j['lastname'] as String,
    gender: j['gender'].toString(),
    dateOfBirth: DateTime.parse(j['dateofbirth'] as String),
    physicalAddress: j['physicaladdress'] as String?,
    enrollmentStatus: j['enrollmentstatus'].toString(),
  );

  Map<String, dynamic> toInsertJson() => {
    'firstname': firstName,
    'middlename': middleName,
    'lastname': lastName,
    'gender': gender,
    'dateofbirth': dateOfBirth.toIso8601String().substring(0, 10),
    'physicaladdress': physicalAddress,
    'enrollmentstatus': enrollmentStatus,
  };

  Map<String, dynamic> toUpdateJson() => {
    'firstname': firstName,
    'middlename': middleName,
    'lastname': lastName,
    'gender': gender,
    'physicaladdress': physicalAddress,
  };

  @override
  String toString() => 'Student($studentId, $fullName)';
}
