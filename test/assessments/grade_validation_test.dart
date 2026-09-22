import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/assessments/data/grade_repository.dart';

void main() {
  group('validateScore', () {
    test('returns null for empty string', () {
      expect(validateScore('', 100), isNull);
    });

    test('returns the parsed score for a valid value', () {
      expect(validateScore('75', 100), 75.0);
      expect(validateScore('0', 100), 0.0);
      expect(validateScore('100', 100), 100.0);
    });

    test('throws FormatException for non-numeric input', () {
      expect(() => validateScore('abc', 100), throwsFormatException);
    });

    test('throws FormatException for negative score', () {
      expect(() => validateScore('-1', 100), throwsFormatException);
    });

    test('throws FormatException when score exceeds maxScore', () {
      expect(() => validateScore('101', 100), throwsFormatException);
      expect(() => validateScore('100.5', 100), throwsFormatException);
    });

    test('accepts decimal scores within range', () {
      expect(validateScore('55.5', 100), 55.5);
    });
  });
}
