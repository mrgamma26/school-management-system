import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/export_service.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../settings/presentation/settings_providers.dart';
import '../../data/receipt_email_service.dart';
import '../../domain/models/payment_receipt.dart';
import '../../domain/receipt_email.dart';
import 'email_receipt_dialog.dart';

/// The official receipt shown in place right after a payment is posted.
///
/// School name and logo come from the branding providers. Print and Download
/// PDF use [ExportService]. Email sends a plain-text receipt summary (no
/// attachment) to the guardians the accountant picks, through the existing
/// notification path.
class ReceiptCard extends ConsumerStatefulWidget {
  final PaymentReceiptData receipt;
  final String studentId;
  final VoidCallback onDone;

  const ReceiptCard({
    super.key,
    required this.receipt,
    required this.studentId,
    required this.onDone,
  });

  @override
  ConsumerState<ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends ConsumerState<ReceiptCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failure ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailReceipt(
    String schoolName,
    List<ReceiptRecipient> guardians,
  ) async {
    final chosen = await showDialog<List<ReceiptRecipient>>(
      context: context,
      builder: (_) => EmailReceiptDialog(
        receipt: widget.receipt,
        schoolName: schoolName,
        guardians: guardians,
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final result = await ref.read(receiptEmailSenderProvider)(
        receipt: widget.receipt,
        schoolName: schoolName,
        recipients: chosen,
      );
      message = receiptEmailOutcomeMessage(result);
    } catch (e) {
      message = 'Could not email the receipt. ${friendlyError(e)}';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// The Email receipt button, or an honest reason it cannot be used.
  ({Widget button, String? note}) _emailAction(String schoolName) {
    final async = ref.watch(receiptRecipientsProvider(widget.studentId));
    return async.when(
      loading: () => (
        button: const Tooltip(
          message: 'Checking the guardians linked to this student…',
          child: UiButton.secondary(
            'Email receipt',
            icon: Icons.mail_outline,
            onPressed: null,
          ),
        ),
        note: null,
      ),
      error: (_, _) => (
        button: const Tooltip(
          message: 'The linked guardians could not be loaded.',
          child: UiButton.secondary(
            'Email receipt',
            icon: Icons.mail_outline,
            onPressed: null,
          ),
        ),
        note:
            'Email receipt is unavailable because the linked guardians could not be loaded.',
      ),
      data: (guardians) {
        final note = noRecipientNote(guardians);
        if (note != null) {
          return (
            button: Tooltip(
              message: note,
              child: const UiButton.secondary(
                'Email receipt',
                icon: Icons.mail_outline,
                onPressed: null,
              ),
            ),
            note: 'Email receipt is unavailable. $note',
          );
        }
        return (
          button: UiButton.secondary(
            'Email receipt',
            icon: Icons.mail_outline,
            onPressed: _busy ? null : () => _emailReceipt(schoolName, guardians),
          ),
          note: null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    final branding = ref
        .watch(schoolBrandingProvider)
        .maybeWhen(data: (b) => b, orElse: () => null);
    final schoolName = branding?.schoolName ?? 'School';
    final logoUrl = ref
        .watch(schoolSettingsRepositoryProvider)
        .publicLogoUrl(branding?.logoPath);

    final email = _emailAction(schoolName);

    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    return Panel(
      title: 'Payment receipt',
      trailing: StatusPill('Posted', tone: StatusTone.success),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: logoUrl != null
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Text(
                          initialsOf(schoolName),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      )
                    : Text(
                        initialsOf(schoolName),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'OFFICIAL PAYMENT RECEIPT',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SelectableText(
                r.receiptNumber,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 6),
          line('Received from', r.studentName),
          if (r.className != null) line('Class', r.className!),
          line('Payment date', formatUiDate(r.paymentDate)),
          line('Applied to', r.feeType),
          line('Method', r.methodLabel),
          if (r.reference != null && r.reference!.isNotEmpty)
            line('Reference', r.reference!),
          const Divider(height: 18),
          line('Amount received', formatMwk(r.amount), strong: true),
          line('Previous balance', formatMwk(r.previousBalance)),
          line('Remaining balance', formatMwk(r.remainingBalance), strong: true),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              UiButton.secondary(
                'Print',
                icon: Icons.print_outlined,
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ExportService.printReceipt(r),
                        'Could not open the print dialog.',
                      ),
              ),
              UiButton.secondary(
                'Download PDF',
                icon: Icons.download_outlined,
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ExportService.downloadReceiptPdf(r),
                        'Could not create the PDF.',
                      ),
              ),
              email.button,
              UiButton('Done', icon: Icons.check, onPressed: widget.onDone),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            email.note ??
                'Email receipt sends a plain-text summary to the guardians you '
                    'choose; it has no PDF attachment. Print or download the PDF '
                    'to hand over a copy.',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
