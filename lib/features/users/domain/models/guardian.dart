/// Guardian profile row from the [guardian] table.
///
/// Note: [userId] is nullable - guardians can exist without a system login.
class Guardian {
  final String guardianId;
  final String? userId; // nullable: guardian may not have a system account
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String? phoneNumber;
  final String? physicalAddress;
  final String? email;

  const Guardian({
    required this.guardianId,
    this.userId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    this.phoneNumber,
    this.physicalAddress,
    this.email,
  });

  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((p) => p != null && p.isNotEmpty).join(' ');

  factory Guardian.fromJson(Map<String, dynamic> j) => Guardian(
    guardianId: j['guardianid'] as String,
    userId: j['userid'] as String?,
    firstName: j['firstname'] as String,
    middleName: j['middlename'] as String?,
    lastName: j['lastname'] as String,
    gender: j['gender'].toString(),
    phoneNumber: j['phonenumber'] as String?,
    physicalAddress: j['physicaladdress'] as String?,
    email: j['email'] as String?,
  );

  Map<String, dynamic> toUpdateJson() => {
    'firstname': firstName,
    'middlename': middleName,
    'lastname': lastName,
    'gender': gender,
    'phonenumber': phoneNumber,
    'physicaladdress': physicalAddress,
    'email': email,
  };

  @override
  String toString() => 'Guardian($guardianId, $fullName)';
}
