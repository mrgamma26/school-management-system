/// Everything printed on an official payment receipt.
///
/// Built from the values returned by `record_payment_v2` plus the balance the
/// account had immediately before and after the payment. The school name and
/// logo are not stored here: they come from the branding providers (screen) or
/// from [ExportService] (PDF) so there is a single source for them.
class PaymentReceiptData {
  final String receiptNumber;
  final String paymentId;
  final String studentName;
  final String? className;
  final String feeType;
  final DateTime paymentDate;
  final double amount;
  final String method;
  final String? reference;
  final double previousBalance;
  final double remainingBalance;

  const PaymentReceiptData({
    required this.receiptNumber,
    required this.paymentId,
    required this.studentName,
    required this.className,
    required this.feeType,
    required this.paymentDate,
    required this.amount,
    required this.method,
    required this.reference,
    required this.previousBalance,
    required this.remainingBalance,
  });

  String get methodLabel => method.replaceAll('_', ' ');
}
