import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/finance/data/finance_records_repository.dart';

void main() {
  test(
    'partial payments remain visible before an instalment is fully covered',
    () {
      final arrangement = PaymentArrangementRow.fromJson({
        'arrangement_id': 'arrangement-1',
        'student': {'firstname': 'Test', 'lastname': 'Learner'},
        'total_amount': 300,
        'paid_amount': 75,
        'status': 'ACTIVE',
        'payment_arrangement_installments': [
          {'due_date': '2026-10-31', 'amount': 100, 'status': 'PENDING'},
          {'due_date': '2026-11-30', 'amount': 200, 'status': 'PENDING'},
        ],
      });

      expect(arrangement.paidAmount, 75);
      expect(arrangement.remainingAmount, 225);
      expect(arrangement.paidInstallments, 0);
    },
  );

  test('remaining amount never renders below zero after an overpayment', () {
    final arrangement = PaymentArrangementRow.fromJson({
      'arrangement_id': 'arrangement-2',
      'student': {'firstname': 'Test', 'lastname': 'Learner'},
      'total_amount': 100,
      'paid_amount': 125,
      'status': 'COMPLETED',
      'payment_arrangement_installments': const [],
    });

    expect(arrangement.paidAmount, 125);
    expect(arrangement.remainingAmount, 0);
  });
}
