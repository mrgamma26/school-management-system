/// Staff profile row from the [staff] table.
class Staff {
  final String staffId;
  final String userId;
  final String employeeNumber;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String email;

  const Staff({
    required this.staffId,
    required this.userId,
    required this.employeeNumber,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    required this.email,
  });

  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((p) => p != null && p.isNotEmpty).join(' ');

  factory Staff.fromJson(Map<String, dynamic> j) => Staff(
    staffId: j['staffid'] as String,
    userId: j['userid'] as String,
    employeeNumber: j['employeenumber'] as String,
    firstName: j['firstname'] as String,
    middleName: j['middlename'] as String?,
    lastName: j['lastname'] as String,
    gender: j['gender'].toString(),
    email: j['email'] as String,
  );

  Map<String, dynamic> toUpdateJson() => {
    'firstname': firstName,
    'middlename': middleName,
    'lastname': lastName,
    'gender': gender,
    'email': email,
  };

  @override
  String toString() => 'Staff($staffId, $fullName)';
}
