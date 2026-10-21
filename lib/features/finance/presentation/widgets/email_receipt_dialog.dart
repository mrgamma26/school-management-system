import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../domain/models/payment_receipt.dart';
import '../../domain/receipt_email.dart';

/// Confirmation step for "Email receipt": lists every linked guardian, lets
/// the accountant tick who receives it (default: all with an email address)
/// and states exactly who will be emailed. Pops with the chosen recipients, or
/// null when cancelled.
class EmailReceiptDialog extends StatefulWidget {
  final PaymentReceiptData receipt;
  final String schoolName;
  final List<ReceiptRecipient> guardians;

  const EmailReceiptDialog({
    super.key,
    required this.receipt,
    required this.schoolName,
    required this.guardians,
  });

  @override
  State<EmailReceiptDialog> createState() => _EmailReceiptDialogState();
}

class _EmailReceiptDialogState extends State<EmailReceiptDialog> {
  late final Set<String> _selected = defaultRecipientSelection(
    widget.guardians,
  );

  @override
  Widget build(BuildContext context) {
    final chosen = selectedRecipients(widget.guardians, _selected);
    final r = widget.receipt;
    return AlertDialog(
      title: const Text('Email receipt'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receipt ${r.receiptNumber} for ${r.studentName} '
                '(${formatMwk(r.amount)}) will be emailed as plain text. '
                'It shows the school name, receipt number, student, amount, '
                'date, method and remaining balance.',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              for (final g in widget.guardians)
                CheckboxListTile(
                  key: ValueKey('receipt-guardian-${g.guardianId}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: g.hasEmail && _selected.contains(g.guardianId),
                  onChanged: g.hasEmail
                      ? (on) => setState(() {
                          if (on == true) {
                            _selected.add(g.guardianId);
                          } else {
                            _selected.remove(g.guardianId);
                          }
                        })
                      : null,
                  title: Text(
                    g.relationship == null || g.relationship!.trim().isEmpty
                        ? g.name
                        : '${g.name} (${g.relationship})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    g.hasEmail ? g.email!.trim() : 'No email address on file',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                chosen.isEmpty
                    ? 'Select at least one guardian to send this receipt.'
                    : 'Will be sent to: '
                          '${chosen.map((g) => '${g.name} <${g.email!.trim()}>').join(', ')}.',
                key: const ValueKey('receipt-email-summary'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(chosen),
          child: Text(
            'Send to ${chosen.length} guardian${chosen.length == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }
}
