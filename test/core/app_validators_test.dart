import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/validation/app_validators.dart';

void main() {
  group('AppValidators', () {
    test('normalizes repeated whitespace', () {
      expect(AppValidators.normalizeSpaces('  Mai   Halima '), 'Mai Halima');
    });

    test('validates Malawi mobile formats', () {
      expect(AppValidators.malawiPhone('0991234567', required: true), isNull);
      expect(
        AppValidators.malawiPhone('+265991234567', required: true),
        isNull,
      );
      expect(
        AppValidators.malawiPhone('0712345678', required: true),
        isNotNull,
      );
    });

    test(
      'validates and canonicalizes a fixed-prefix Malawi subscriber number',
      () {
        expect(AppValidators.malawiSubscriberDigits('991234567'), isNull);
        expect(AppValidators.malawiSubscriberDigits('99123456'), isNotNull);
        expect(AppValidators.malawiSubscriberDigits('9912345678'), isNotNull);
        expect(AppValidators.malawiSubscriberDigits('99A234567'), isNotNull);
        expect(
          AppValidators.canonicalMalawiPhone('991234567'),
          '+265991234567',
        );
      },
    );

    test(
      'extracts editable digits from canonical and legacy stored numbers',
      () {
        expect(
          AppValidators.malawiSubscriberFromStored('+265 991 234 567'),
          '991234567',
        );
        expect(
          AppValidators.malawiSubscriberFromStored('0991234567'),
          '991234567',
        );
        expect(
          AppValidators.malawiSubscriberFromStored('991234567'),
          '991234567',
        );
        expect(AppValidators.malawiSubscriberFromStored('+266991234567'), '');
      },
    );

    test('requires staff to be at least eighteen', () {
      final today = DateTime(2026, 10, 16);
      expect(
        AppValidators.staffBirthDate(DateTime(2008, 10, 16), today: today),
        isNull,
      );
      expect(
        AppValidators.staffBirthDate(DateTime(2008, 10, 17), today: today),
        isNotNull,
      );
    });

    test('validates names and email addresses', () {
      expect(AppValidators.requiredName("  Chikondi O'Brien "), isNull);
      // Any name is accepted, including digits (for example "E2E"); blank and over-long are not.
      expect(AppValidators.requiredName('E2E'), isNull);
      expect(AppValidators.requiredName('1234'), isNull);
      expect(AppValidators.requiredName('   '), isNotNull);
      expect(AppValidators.requiredName('A' * 81), isNotNull);
      expect(AppValidators.email('teacher@school.mw'), isNull);
      expect(AppValidators.email('teacher-at-school'), isNotNull);
    });
  });
}
