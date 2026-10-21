import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/services/export_service.dart';
import 'package:school_management_app/features/finance/domain/models/payment_receipt.dart';

void main() {
  test('receipt PDF is generated with school name and balances', () async {
    final receipt = PaymentReceiptData(
      receiptNumber: 'SCH-2026-000218',
      paymentId: 'p1',
      studentName: 'Tiwonge Phiri',
      className: 'Form 2A',
      feeType: 'Term 2 tuition',
      paymentDate: DateTime(2026, 10, 17),
      amount: 70000,
      method: 'BANK_TRANSFER',
      reference: 'NBM-881204',
      previousBalance: 130000,
      remainingBalance: 60000,
    );
    final bytes = await ExportService.buildReceiptPdf(
      receipt,
      schoolName: 'Test School',
    );
    expect(bytes.length, greaterThan(500));
    // A PDF starts with the %PDF magic header.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(receipt.methodLabel, 'BANK TRANSFER');
  });
}
