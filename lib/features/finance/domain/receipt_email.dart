import '../../../widgets/ui_kit.dart' show formatMwk, formatUiDate;
import 'models/payment_receipt.dart';

/// Pure rules for emailing a payment receipt to a student's guardians.
///
/// The email goes out through the existing notification path: one `notification`
/// row per guardian, which the database trigger and the
/// `send-notification-email` Edge Function turn into an email.

/// One guardian linked to the student (`studentguardian` -> `guardian`).
class ReceiptRecipient {
  final String guardianId;
  final String name;
  final String? email;
  final String? relationship;

  const ReceiptRecipient({
    required this.guardianId,
    required this.name,
    this.email,
    this.relationship,
  });

  /// True when [email] looks like a deliverable address.
  bool get hasEmail => isUsableEmail(email);
}

final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool isUsableEmail(String? value) =>
    value != null && _emailShape.hasMatch(value.trim());

/// Guardians who can receive the receipt, in the given order, each guardian
/// once even if the link row is repeated.
List<ReceiptRecipient> recipientsWithEmail(
  Iterable<ReceiptRecipient> guardians,
) {
  final seen = <String>{};
  return [
    for (final g in guardians)
      if (g.hasEmail && seen.add(g.guardianId)) g,
  ];
}

/// Ids selected by default: every guardian with an email address.
Set<String> defaultRecipientSelection(Iterable<ReceiptRecipient> guardians) => {
  for (final g in recipientsWithEmail(guardians)) g.guardianId,
};

/// The guardians that will actually receive the email: those in [selectedIds]
/// that have an email address. Order follows [guardians].
List<ReceiptRecipient> selectedRecipients(
  Iterable<ReceiptRecipient> guardians,
  Set<String> selectedIds,
) => [
  for (final g in recipientsWithEmail(guardians))
    if (selectedIds.contains(g.guardianId)) g,
];

/// Honest note shown instead of the action when nobody can be emailed, or null
/// when at least one linked guardian has an email address.
String? noRecipientNote(Iterable<ReceiptRecipient> guardians) {
  final all = guardians.toList();
  if (all.isEmpty) {
    return 'No guardian is linked to this student, so there is nobody to email.';
  }
  if (recipientsWithEmail(all).isEmpty) {
    return 'No linked guardian has an email address on file.';
  }
  return null;
}

String receiptEmailSubject(PaymentReceiptData receipt) =>
    'Payment receipt ${receipt.receiptNumber}';

/// Plain-text body. Carries only what the printed receipt already shows (no
/// payment reference, card or phone details).
String buildReceiptEmailMessage({
  required String schoolName,
  required PaymentReceiptData receipt,
}) {
  final school = schoolName.trim().isEmpty ? 'School' : schoolName.trim();
  return [
    'Payment receipt from $school',
    '',
    'Receipt number: ${receipt.receiptNumber}',
    'Student: ${receipt.studentName}',
    'Amount received: ${formatMwk(receipt.amount)}',
    'Payment date: ${formatUiDate(receipt.paymentDate)}',
    'Method: ${receipt.methodLabel}',
    'Remaining balance: ${formatMwk(receipt.remainingBalance)}',
    '',
    'Thank you for your payment.',
  ].join('\n');
}
