class AppValidators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _malawiPhone = RegExp(r'^(?:(?:\+265)|0)(?:88|89|98|99)\d{7}$');
  static final _malawiSubscriber = RegExp(r'^\d{9}$');

  static String normalizeSpaces(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? requiredName(String? value, {String label = 'Name'}) {
    final normalized = normalizeSpaces(value ?? '');
    if (normalized.isEmpty) return '$label is required.';
    if (normalized.length > 80) return '$label must be 80 characters or fewer.';
    // Any text is accepted (letters, digits, symbols): schools use names such as
    // "E2E", "O'Brien" or "Mary-Jane" and the rule was rejecting real data.
    return null;
  }

  static String? optionalName(String? value, {String label = 'Name'}) {
    if ((value ?? '').trim().isEmpty) return null;
    return requiredName(value, label: label);
  }

  static String? email(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return 'Email is required.';
    return _email.hasMatch(normalized) ? null : 'Enter a valid email address.';
  }

  static String? malawiPhone(String? value, {bool required = false}) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (normalized.isEmpty) {
      return required ? 'Phone number is required.' : null;
    }
    return _malawiPhone.hasMatch(normalized)
        ? null
        : 'Use a Malawi mobile number such as 0991234567 or +265991234567.';
  }

  /// Validates the nine editable digits shown after the fixed +265 prefix.
  static String? malawiSubscriberDigits(
    String? value, {
    bool required = false,
  }) {
    final digits = (value ?? '').trim();
    if (digits.isEmpty) {
      return required ? 'Phone number is required.' : null;
    }
    return _malawiSubscriber.hasMatch(digits)
        ? null
        : 'Enter exactly 9 digits after +265.';
  }

  /// Converts the editable subscriber digits to the value stored by the API.
  static String? canonicalMalawiPhone(String? subscriberDigits) {
    final digits = (subscriberDigits ?? '').trim();
    if (digits.isEmpty) return null;
    return malawiSubscriberDigits(digits) == null ? '+265$digits' : null;
  }

  /// Converts canonical or legacy stored values to the nine editable digits.
  static String malawiSubscriberFromStored(String? value) {
    var normalized = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (normalized.startsWith('+265')) {
      normalized = normalized.substring(4);
    } else if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }
    return _malawiSubscriber.hasMatch(normalized) ? normalized : '';
  }

  static String? staffBirthDate(DateTime? value, {DateTime? today}) {
    if (value == null) return 'Date of birth is required.';
    final now = today ?? DateTime.now();
    final eighteenthBirthday = DateTime(
      value.year + 18,
      value.month,
      value.day,
    );
    return eighteenthBirthday.isAfter(DateTime(now.year, now.month, now.day))
        ? 'Staff members must be at least 18 years old.'
        : null;
  }
}
