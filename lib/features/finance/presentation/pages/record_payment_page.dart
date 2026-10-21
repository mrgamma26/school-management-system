import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../widgets/ui_kit.dart';
import '../../data/finance_repository.dart';
import '../widgets/payment_form_fields.dart';

/// Screen 41 - Record a payment for one student.
///
/// The Student Account workspace records payments in place; this standalone
/// page remains for direct links and asks for the academic period first.
class RecordPaymentPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  const RecordPaymentPage({
    required this.studentId,
    required this.studentName,
    super.key,
  });
  @override
  State<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends State<RecordPaymentPage> {
  final _fields = GlobalKey<PaymentFormFieldsState>();
  final _financeRepo = FinanceRepository();
  PaymentFormSnapshot? _snapshot;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final request = _fields.currentState?.validate();
    if (request == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _financeRepo.recordPayment(
        studentId: widget.studentId,
        feeStructureId: request.fee.feeStructureId,
        amount: request.amount,
        paymentDate: request.paymentDate,
        method: request.method,
        referenceNumber: request.referenceNumber,
        channelId: request.channelId,
        processingFee: request.processingFee,
        transactionDetails: request.transactionDetails,
      );

      String? evidenceWarning;
      if (request.method == 'DEPOSIT' &&
          request.depositSlipBytes != null &&
          request.depositSlipName != null) {
        try {
          await _financeRepo.attachDepositSlip(
            studentId: widget.studentId,
            paymentId: result.paymentId,
            bankName:
                request.transactionDetails['depositBankName']?.toString() ?? '',
            reference: request.referenceNumber ?? result.receiptNumber,
            amount: request.amount,
            depositDate: request.paymentDate,
            bytes: request.depositSlipBytes!,
            fileName: request.depositSlipName!,
          );
        } catch (_) {
          evidenceWarning =
              '\n\nThe payment was recorded, but its deposit slip could not '
              'be attached. Open the student account and retry the evidence '
              'upload before verifying the deposit.';
        }
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            evidenceWarning == null ? Icons.check_circle : Icons.warning_amber,
            color: evidenceWarning == null ? Colors.green : Colors.orange,
            size: 42,
          ),
          title: Text(
            evidenceWarning == null
                ? 'Payment Recorded'
                : 'Payment Recorded — Evidence Pending',
          ),
          content: SelectableText(
            'School receipt: ${result.receiptNumber}\n\n'
            'This payment is now available in account and guardian history.'
            '${evidenceWarning ?? ''}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typedAmount = _snapshot?.amount;
    return FormPageLayout(
      kicker: 'Finance · Student account',
      title: 'Record Payment',
      subtitle: widget.studentName,
      formTitle: 'Payment details',
      saving: _loading,
      saveLabel: 'Record Payment',
      onSave: _submit,
      error: _error,
      guideTitle: 'Receipt:',
      guide:
          'A unique school receipt number will be generated automatically. Posted payments are immutable — mistakes are corrected by reversal, never by editing.',
      sideTitle: 'Payment summary',
      side: [
        UiCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              DetailLine('Student', widget.studentName),
              DetailLine('Fee', _snapshot?.fee?.feeType ?? '—'),
              DetailLine(
                'Amount',
                typedAmount == null ? '—' : formatMwk(typedAmount),
              ),
              DetailLine(
                'Method',
                (_snapshot?.method ?? 'CASH').replaceAll('_', ' '),
              ),
              DetailLine(
                'Date',
                formatUiDate(_snapshot?.date ?? DateTime.now()),
              ),
            ],
          ),
        ),
      ],
      form: PaymentFormFields(
        key: _fields,
        onChanged: (s) {
          if (mounted) setState(() => _snapshot = s);
        },
      ),
    );
  }
}
