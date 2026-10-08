import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/students/data/student_repository.dart';
import 'package:school_management_app/features/users/data/repositories/user_repository.dart';
import 'package:school_management_app/features/finance/data/finance_repository.dart';

void main() {
  group('Pagination constants', () {
    test('kStudentPageSize is positive and reasonable', () {
      expect(kStudentPageSize, greaterThan(0));
      expect(kStudentPageSize, lessThanOrEqualTo(5000));
    });

    test('kUserPageSize is positive and reasonable', () {
      expect(kUserPageSize, greaterThan(0));
      expect(kUserPageSize, lessThanOrEqualTo(5000));
    });

    test('kPaymentPageSize is positive and reasonable', () {
      expect(kPaymentPageSize, greaterThan(0));
      expect(kPaymentPageSize, lessThanOrEqualTo(5000));
    });

    test('page sizes are consistent — user list is not larger than student list', () {
      // A school has fewer staff than students, so this ordering makes sense.
      expect(kUserPageSize, lessThanOrEqualTo(kStudentPageSize));
    });
  });
}
