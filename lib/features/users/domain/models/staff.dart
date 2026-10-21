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
  final DateTime? dateOfBirth;
  final String? nationalId;
  final String? phoneNumber;
  final String? alternativePhone;
  final String? physicalAddress;
  final String? profilePicturePath;
  final String? jobTitle;
  final String? department;
  final String? employmentType;
  final String employmentStatus;
  final DateTime? employmentStartDate;
  final String? professionalQualifications;
  final String? highestAcademicQualification;
  final int? yearsOfExperience;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelationship;

  const Staff({
    required this.staffId,
    required this.userId,
    required this.employeeNumber,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    required this.email,
    this.dateOfBirth,
    this.nationalId,
    this.phoneNumber,
    this.alternativePhone,
    this.physicalAddress,
    this.profilePicturePath,
    this.jobTitle,
    this.department,
    this.employmentType,
    this.employmentStatus = 'ACTIVE',
    this.employmentStartDate,
    this.professionalQualifications,
    this.highestAcademicQualification,
    this.yearsOfExperience,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
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
    dateOfBirth: DateTime.tryParse(j['dateofbirth']?.toString() ?? ''),
    nationalId: j['nationalid'] as String?,
    phoneNumber: j['phonenumber'] as String?,
    alternativePhone: j['alternativephone'] as String?,
    physicalAddress: j['physicaladdress'] as String?,
    profilePicturePath: j['profilepicturepath'] as String?,
    jobTitle: j['jobtitle'] as String?,
    department: j['department'] as String?,
    employmentType: j['employmenttype'] as String?,
    employmentStatus: j['employmentstatus'] as String? ?? 'ACTIVE',
    employmentStartDate: DateTime.tryParse(
      j['employmentstartdate']?.toString() ?? '',
    ),
    professionalQualifications: j['professionalqualifications'] as String?,
    highestAcademicQualification: j['highestacademicqualification'] as String?,
    yearsOfExperience: (j['yearsofexperience'] as num?)?.toInt(),
    emergencyContactName: j['emergencycontactname'] as String?,
    emergencyContactPhone: j['emergencycontactphone'] as String?,
    emergencyContactRelationship: j['emergencycontactrelationship'] as String?,
  );

  Map<String, dynamic> toUpdateJson() => {
    'firstname': firstName,
    'middlename': middleName,
    'lastname': lastName,
    'gender': gender,
    'email': email,
    'dateofbirth': dateOfBirth?.toIso8601String().split('T').first,
    'nationalid': nationalId,
    'phonenumber': phoneNumber,
    'alternativephone': alternativePhone,
    'physicaladdress': physicalAddress,
    'profilepicturepath': profilePicturePath,
    'jobtitle': jobTitle,
    'department': department,
    'employmenttype': employmentType,
    'employmentstatus': employmentStatus,
    'employmentstartdate': employmentStartDate
        ?.toIso8601String()
        .split('T')
        .first,
    'professionalqualifications': professionalQualifications,
    'highestacademicqualification': highestAcademicQualification,
    'yearsofexperience': yearsOfExperience,
    'emergencycontactname': emergencyContactName,
    'emergencycontactphone': emergencyContactPhone,
    'emergencycontactrelationship': emergencyContactRelationship,
  };

  @override
  String toString() => 'Staff($staffId, $fullName)';
}
