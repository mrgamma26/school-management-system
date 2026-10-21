import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/finance/domain/models/payment.dart';

void main() {
  group('Payment.fromJson', () {
    const baseJson = {
      'paymentid': 'pay-001',
      'studentid': 'stu-001',
      'feestructureid': 'fee-001',
      'recordedby': 'staff-001',
      'amount': 5000.00,
      'paymentdate': '2024-03-15',
      'method': 'CASH',
      'referencenumber': null,
      'receiptnumber': null,
    };

    test('parses all required fields', () {
      final p = Payment.fromJson(baseJson);
      expect(p.paymentId, 'pay-001');
      expect(p.studentId, 'stu-001');
      expect(p.feeStructureId, 'fee-001');
      expect(p.recordedBy, 'staff-001');
      expect(p.amount, 5000.0);
      expect(p.paymentDate, DateTime(2024, 3, 15));
      expect(p.method, 'CASH');
    });

    test('optional fields are null when absent', () {
      final p = Payment.fromJson(baseJson);
      expect(p.referenceNumber, isNull);
      expect(p.receiptNumber, isNull);
      expect(p.studentName, isNull);
      expect(p.feeType, isNull);
    });

    test('resolves joined student name', () {
      final json = {
        ...baseJson,
        'student': {'firstname': 'Amina', 'lastname': 'Hassan'},
      };
      final p = Payment.fromJson(json);
      expect(p.studentName, 'Amina Hassan');
    });

    test('resolves joined fee type', () {
      final json = {
        ...baseJson,
        'feestructure': {'feetype': 'TUITION'},
      };
      final p = Payment.fromJson(json);
      expect(p.feeType, 'TUITION');
    });

    test('parses integer amount as double', () {
      final json = {...baseJson, 'amount': 1000};
      final p = Payment.fromJson(json);
      expect(p.amount, 1000.0);
      expect(p.amount, isA<double>());
    });

    test('parses optional reference and receipt numbers', () {
      final json = {
        ...baseJson,
        'referencenumber': 'REF-2024-001',
        'receiptnumber': 'REC-0042',
      };
      final p = Payment.fromJson(json);
      expect(p.referenceNumber, 'REF-2024-001');
      expect(p.receiptNumber, 'REC-0042');
    });
  });

  group('kPaymentMethods', () {
    test('contains all 7 expected methods', () {
      expect(kPaymentMethods, hasLength(7));
      expect(kPaymentMethods, contains('CASH'));
      expect(kPaymentMethods, contains('DEPOSIT'));
      expect(kPaymentMethods, contains('BANK_TRANSFER'));
      expect(kPaymentMethods, contains('MOBILE_MONEY'));
    });
  });
}
