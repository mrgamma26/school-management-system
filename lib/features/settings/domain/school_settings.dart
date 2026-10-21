class SchoolBranding {
  final String schoolName;
  final String? logoPath;
  final String? motto;

  const SchoolBranding({required this.schoolName, this.logoPath, this.motto});

  factory SchoolBranding.fromJson(Map<String, dynamic> json) => SchoolBranding(
    schoolName: (json['school_name'] as String?)?.trim().isNotEmpty == true
        ? (json['school_name'] as String).trim()
        : 'School Management System',
    logoPath: json['logo_path'] as String?,
    motto: json['motto'] as String?,
  );
}

class SchoolSettings extends SchoolBranding {
  final String settingsId;
  final String? physicalAddress;
  final String? postalAddress;
  final String? phoneNumber;
  final String? emailAddress;
  final String? website;
  final String defaultCurrency;
  final String? receiptFooter;
  final int studentMinimumAge;
  final int? studentMaximumAge;
  final int staffMinimumAge;
  final List<String> acceptedPaymentMethods;
  final String balanceCarryForwardPolicy;
  final int? overdueDayOfTerm;
  final int depositSlipMaxBytes;
  final List<String> depositSlipMimeTypes;

  const SchoolSettings({
    required this.settingsId,
    required super.schoolName,
    super.logoPath,
    super.motto,
    this.physicalAddress,
    this.postalAddress,
    this.phoneNumber,
    this.emailAddress,
    this.website,
    required this.defaultCurrency,
    this.receiptFooter,
    required this.studentMinimumAge,
    this.studentMaximumAge,
    required this.staffMinimumAge,
    required this.acceptedPaymentMethods,
    required this.balanceCarryForwardPolicy,
    this.overdueDayOfTerm,
    required this.depositSlipMaxBytes,
    required this.depositSlipMimeTypes,
  });

  factory SchoolSettings.fromJson(Map<String, dynamic> json) => SchoolSettings(
    settingsId: json['settings_id'] as String,
    schoolName: json['school_name'] as String,
    logoPath: json['logo_path'] as String?,
    motto: json['motto'] as String?,
    physicalAddress: json['physical_address'] as String?,
    postalAddress: json['postal_address'] as String?,
    phoneNumber: json['phone_number'] as String?,
    emailAddress: json['email_address'] as String?,
    website: json['website'] as String?,
    defaultCurrency: json['default_currency'] as String? ?? 'MWK',
    receiptFooter: json['receipt_footer'] as String?,
    studentMinimumAge: json['student_minimum_age'] as int? ?? 9,
    studentMaximumAge: json['student_maximum_age'] as int?,
    staffMinimumAge: json['staff_minimum_age'] as int? ?? 18,
    acceptedPaymentMethods: List<String>.from(
      json['accepted_payment_methods'] as List? ??
          const ['CASH', 'BANK_DEPOSIT'],
    ),
    balanceCarryForwardPolicy:
        json['balance_carry_forward_policy'] as String? ?? 'NEXT_TERM',
    overdueDayOfTerm: json['overdue_day_of_term'] as int?,
    depositSlipMaxBytes: json['deposit_slip_max_bytes'] as int? ?? 5242880,
    depositSlipMimeTypes: List<String>.from(
      json['deposit_slip_mime_types'] as List? ??
          const ['image/jpeg', 'image/png', 'image/webp'],
    ),
  );

  Map<String, dynamic> toUpdateJson(String userId) => {
    'school_name': schoolName.trim(),
    'logo_path': logoPath,
    'motto': _nullable(motto),
    'physical_address': _nullable(physicalAddress),
    'postal_address': _nullable(postalAddress),
    'phone_number': _nullable(phoneNumber),
    'email_address': _nullable(emailAddress),
    'website': _nullable(website),
    'default_currency': defaultCurrency.trim().toUpperCase(),
    'receipt_footer': _nullable(receiptFooter),
    'student_minimum_age': 9,
    'student_maximum_age': null,
    'staff_minimum_age': 18,
    'accepted_payment_methods': acceptedPaymentMethods,
    'balance_carry_forward_policy': balanceCarryForwardPolicy,
    'overdue_day_of_term': overdueDayOfTerm,
    'deposit_slip_max_bytes': depositSlipMaxBytes,
    'deposit_slip_mime_types': depositSlipMimeTypes,
    'updated_by': userId,
  };

  static String? _nullable(String? value) {
    final normalized = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
