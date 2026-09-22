import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/students/domain/student.dart';

void main() {
  group('Student', () {
    test('parses from JSON', () {
      final json = {
        'studentid': 'student-uuid-001',
        'firstname': 'Amina',
        'middlename': null,
        'lastname': 'Hassan',
        'gender': 'FEMALE',
        'dateofbirth': '2010-03-15',
        'physicaladdress': null,
        'enrollmentstatus': 'ENROLLED',
      };
      final s = Student.fromJson(json);
      expect(s.studentId, 'student-uuid-001');
      expect(s.firstName, 'Amina');
      expect(s.lastName, 'Hassan');
      expect(s.fullName, 'Amina Hassan');
      expect(s.enrollmentStatus, 'ENROLLED');
      expect(s.dateOfBirth, DateTime(2010, 3, 15));
    });

    test('fullName includes middle name when present', () {
      final s = Student(
        studentId: 'x',
        firstName: 'Ali',
        middleName: 'Musa',
        lastName: 'Yusuf',
        gender: 'MALE',
        dateOfBirth: DateTime(2009),
        enrollmentStatus: 'ENROLLED',
      );
      expect(s.fullName, 'Ali Musa Yusuf');
    });

    test('toInsertJson formats date correctly', () {
      final s = Student(
        studentId: 'x',
        firstName: 'Test',
        lastName: 'User',
        gender: 'MALE',
        dateOfBirth: DateTime(2011, 6, 1),
        enrollmentStatus: 'ENROLLED',
      );
      expect(s.toInsertJson()['dateofbirth'], '2011-06-01');
    });
  });
}
