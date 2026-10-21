import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../data/finance_repository.dart';
import '../../data/student_account_repository.dart';
import '../../domain/account_ledger.dart';
import '../../domain/models/fee_structure.dart';
import '../../domain/models/payment_receipt.dart';
import '../finance_account_providers.dart';
import '../widgets/payment_form_fields.dart';
import '../widgets/receipt_card.dart';

/// Screens 39-41 - Student account workspace.
///
/// One page for the accountant: who the student is, what is owed
/// (obligations), what was paid, adjustments and the current balance. A
/// payment is recorded in place with a live preview of the new balance, and the
/// official receipt appears in the same page. Payments are immutable; mistakes
/// are handled by a reversal, which lives on the Payment Reversals page.
class StudentAccountPage extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;

  const StudentAccountPage({
    required this.studentId,
    required this.studentName,
    super.key,
  });

  @override
  ConsumerState<StudentAccountPage> createState() => _StudentAccountPageState();
}

class _StudentAccountPageState extends ConsumerState<StudentAccountPage> {
  final _fields = GlobalKey<PaymentFormFieldsState>();
  final _finance = FinanceRepository();
  int _tab = 0;
  bool _paying = false;
  bool _posting = false;
  String? _error;
  String? _flash;
  PaymentReceiptData? _receipt;
  PaymentFormSnapshot? _snapshot;
  final Set<String> _reversing = {};

  Future<void> _reversePayment(LedgerPayment payment) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reverse payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${payment.receiptNumber ?? 'This payment'} · ${formatMwk(payment.amount)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for reversal',
                hintText: 'Required for the audit trail',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Reverse payment'),
          ),
        ],
      ),
    );
    final reversalReason = reason.text.trim();
    reason.dispose();
    if (confirmed != true || reversalReason.isEmpty || !mounted) return;
    setState(() {
      _reversing.add(payment.paymentId);
      _error = null;
    });
    try {
      await _finance.reversePayment(
        paymentId: payment.paymentId,
        reason: reversalReason,
      );
      ref.invalidate(studentAccountProvider(widget.studentId));
      ref.invalidate(balanceOverviewProvider);
      if (mounted) {
        setState(
          () => _flash = 'Payment reversed. The balance has been restored.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _reversing.remove(payment.paymentId));
    }
  }

  void _openPayment() => setState(() {
    _paying = true;
    _receipt = null;
    _error = null;
    _flash = null;
    _snapshot = null;
  });

  void _closePayment() => setState(() {
    _paying = false;
    _error = null;
  });

  List<FeeStructure> _payableFees(StudentAccount account) =>
      account.obligations;

  FeeStructure? _defaultFee(StudentAccount account) {
    for (final s in account.standings) {
      if (s.remaining > 0) return s.fee;
    }
    final fees = account.obligations;
    return fees.isEmpty ? null : fees.first;
  }

  Future<void> _post(StudentAccount account) async {
    final request = _fields.currentState?.validate();
    if (request == null || _posting) return;
    final previous = account.balance;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final result = await _finance.recordPayment(
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
          await _finance.attachDepositSlip(
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
              ' Payment posted, but the deposit slip could not be attached.';
        }
      }
      // Re-read the account so the remaining balance is the server's truth.
      ref.invalidate(balanceOverviewProvider);
      ref.invalidate(studentAccountProvider(widget.studentId));
      double remaining = roundMoney(previous - request.amount);
      try {
        final fresh = await ref.read(
          studentAccountProvider(widget.studentId).future,
        );
        remaining = fresh.balance;
      } catch (_) {
        // Keep the computed value; the payment itself is already posted.
      }
      if (!mounted) return;
      setState(() {
        _receipt = PaymentReceiptData(
          receiptNumber: result.receiptNumber,
          paymentId: result.paymentId,
          studentName: account.name,
          className: account.currentPlacement?.className,
          feeType: request.fee.feeType,
          paymentDate: request.paymentDate,
          amount: request.amount,
          method: request.method,
          reference: request.referenceNumber,
          previousBalance: previous,
          remainingBalance: remaining,
        );
        _paying = false;
        _snapshot = null;
        _flash =
            'Payment posted as ${result.receiptNumber}. The balance is now ${formatMwk(remaining)}.${evidenceWarning ?? ''}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentAccountProvider(widget.studentId));
    return UiPage(
      children: [
        async.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _head(context, widget.studentName, null),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: LoadingState(message: 'Loading account…'),
              ),
            ],
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _head(context, widget.studentName, null),
              ErrorState(
                error: error,
                onRetry: () =>
                    ref.invalidate(studentAccountProvider(widget.studentId)),
              ),
            ],
          ),
          data: (account) => _content(context, account),
        ),
      ],
    );
  }

  Widget _head(BuildContext context, String name, StudentAccount? account) {
    return PageHead(
      kicker: 'Finance · Student account',
      title: name,
      subtitle: 'Payments are immutable. Reverse a payment, never edit it.',
      actions: [
        UiButton.secondary(
          'All accounts',
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.go('/finance/accounts'),
        ),
        UiButton.secondary(
          'Student profile',
          icon: Icons.person_outline,
          onPressed: () => context.go('/students/${widget.studentId}'),
        ),
        if (account != null && !_paying)
          UiButton(
            'Record payment',
            icon: Icons.payments_outlined,
            onPressed: _openPayment,
          ),
      ],
    );
  }

  Widget _content(BuildContext context, StudentAccount account) {
    final balance = account.balance;
    final guardians = account.guardianNames.isEmpty
        ? null
        : 'Guardian ${account.guardianNames.join(', ')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, account.name, account),
        if (_flash != null) ...[
          UiNotice(
            _flash!,
            tone: StatusTone.success,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 14),
        ],
        ProfileHero(
          name: account.name,
          subtitle: [
            account.classLabel,
            account.enrollmentStatus.replaceAll('_', ' '),
            ?guardians,
          ].join(' · '),
          pill: balance > 0
              ? StatusPill(
                  'Balance due ${formatMwk(balance)}',
                  tone: StatusTone.warning,
                )
              : balance < 0
              ? StatusPill(
                  'In credit ${formatMwk(-balance)}',
                  tone: StatusTone.info,
                )
              : const StatusPill('Paid in full', tone: StatusTone.success),
        ),
        const SizedBox(height: 14),
        if (_receipt != null) ...[
          ReceiptCard(
            receipt: _receipt!,
            studentId: widget.studentId,
            onDone: () => setState(() => _receipt = null),
          ),
          const SizedBox(height: 14),
        ],
        if (_paying) ...[_paymentPanel(account), const SizedBox(height: 14)],
        AdaptiveGrid(
          columns: 4,
          phoneColumns: 2,
          children: [
            MetricCard(
              icon: Icons.request_quote_outlined,
              label: 'Total due',
              value: formatMwk(account.totalDue),
              note: '${account.obligations.length} obligation(s)',
              noteTone: StatusTone.neutral,
            ),
            MetricCard(
              icon: Icons.payments_outlined,
              label: 'Paid',
              value: formatMwk(account.totalPaid),
              note: 'Reversed payments excluded',
              noteTone: StatusTone.neutral,
            ),
            MetricCard(
              icon: Icons.tune_outlined,
              label: 'Adjustments',
              value: formatMwk(account.totalAdjusted),
              note: 'Discounts negative, penalties positive',
              noteTone: StatusTone.neutral,
            ),
            MetricCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Balance',
              value: formatMwk(balance),
              note: balance > 0
                  ? 'Outstanding'
                  : balance < 0
                  ? 'Account in credit'
                  : 'Nothing owed',
              noteTone: balance > 0 ? StatusTone.warning : StatusTone.success,
            ),
          ],
        ),
        TabsBar(
          tabs: [
            'Obligations',
            'Payments (${account.payments.length})',
            'Adjustments (${account.adjustments.length})',
          ],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        switch (_tab) {
          0 => _obligations(account),
          1 => _payments(context, account),
          _ => _adjustments(account),
        },
      ],
    );
  }

  // ── In-place payment ──────────────────────────────────────────────────────

  Widget _paymentPanel(StudentAccount account) {
    final fees = _payableFees(account);
    final standings = {
      for (final s in account.standings) s.fee.feeStructureId: s,
    };
    final selected = _snapshot?.fee ?? _defaultFee(account);
    final remaining = selected == null
        ? 0.0
        : (standings[selected.feeStructureId]?.remaining ?? selected.amount);
    final amount = _snapshot?.amount ?? 0;
    final preview = previewPayment(
      balance: account.balance,
      feeRemaining: remaining,
      amount: amount,
    );
    return Panel(
      title: 'Record payment for ${account.name}',
      trailing: IconButton(
        tooltip: 'Close payment form',
        onPressed: _posting ? null : _closePayment,
        icon: const Icon(Icons.close_rounded, size: 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fees.isEmpty)
            const UiNotice(
              'No fee structure applies to this student, so there is nothing to apply a payment to. Check the student class placement and the fee structures for that period.',
              tone: StatusTone.warning,
              icon: Icons.info_outline,
            )
          else
            PaymentFormFields(
              key: _fields,
              fees: fees,
              initialFee: _defaultFee(account),
              feeLabel: (f) {
                final s = standings[f.feeStructureId];
                final left = s?.remaining ?? f.amount;
                return '${f.feeType} — owes ${formatMwk(left)}';
              },
              onChanged: (s) {
                if (mounted) setState(() => _snapshot = s);
              },
            ),
          const SizedBox(height: 14),
          _previewBlock(selected, preview),
          if (_error != null) UiNotice(_error!, icon: Icons.error_outline),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              UiButton.secondary(
                'Cancel',
                onPressed: _posting ? null : _closePayment,
              ),
              UiButton(
                _posting ? 'Posting…' : 'Post payment and show receipt',
                icon: Icons.check,
                onPressed: _posting || fees.isEmpty
                    ? null
                    : () => _post(account),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewBlock(FeeStructure? fee, PaymentPreview p) {
    Widget tile(String label, String value, {bool strong = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: strong ? AppColors.primarySurface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: strong ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Preview before posting',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        AdaptiveGrid(
          columns: 3,
          mediumColumns: 3,
          phoneColumns: 1,
          children: [
            tile('Current balance', formatMwk(p.previousBalance)),
            tile('This payment', '− ${formatMwk(p.amount)}'),
            tile('New balance', formatMwk(p.newBalance), strong: true),
          ],
        ),
        const SizedBox(height: 10),
        if (fee != null)
          DataTableCard(
            columns: const [
              UiColumn('Applied to', flex: 12),
              UiColumn('Owed', flex: 8),
              UiColumn('This payment', flex: 8),
              UiColumn('Left', flex: 8),
            ],
            rows: [
              UiTableRow([
                UiCellText(fee.feeType, bold: true),
                UiCellText(formatMwk(p.feeRemainingBefore)),
                UiCellText(p.amount > 0 ? '− ${formatMwk(p.amount)}' : '—'),
                UiCellText(formatMwk(p.feeRemainingAfter)),
              ]),
            ],
          ),
        const SizedBox(height: 4),
        const Text(
          'The payment is recorded against the selected fee only; it is not split across other fees.',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        if (p.overFee > 0)
          UiNotice(
            'This is ${formatMwk(p.overFee)} more than is still owed on ${fee?.feeType ?? 'this fee'}.',
            tone: StatusTone.warning,
            icon: Icons.warning_amber_rounded,
          ),
        if (p.createsCredit)
          const UiNotice(
            'After this payment the account would be in credit (negative balance). Check the amount before posting.',
            tone: StatusTone.warning,
            icon: Icons.warning_amber_rounded,
          ),
      ],
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────

  Widget _obligations(StudentAccount account) {
    final standings = account.standings;
    return Panel(
      title: 'Obligations',
      trailing: const PanelNote('Fee structures for the student\'s periods'),
      child: standings.isEmpty
          ? const UiEmptyState(
              icon: Icons.request_quote_outlined,
              title: 'No obligations',
              message:
                  'No fee structure applies: the student has no class placement in a period that has fees.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTableCard(
                  columns: const [
                    UiColumn('Period', flex: 12, hideOnPhone: true),
                    UiColumn('Fee', flex: 12),
                    UiColumn('Amount', flex: 9),
                    UiColumn('Paid', flex: 9),
                    UiColumn('Still owed', flex: 9),
                  ],
                  rows: [
                    for (final s in standings)
                      UiTableRow([
                        UiCellText(s.fee.academicYearLabel ?? '—'),
                        UiCellText(s.fee.feeType, bold: true),
                        UiCellText(formatMwk(s.fee.amount)),
                        UiCellText(formatMwk(s.paid)),
                        UiCellText(formatMwk(s.remaining), bold: true),
                      ]),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Adjustments are student-level and are not allocated to a single fee, so they appear only in the overall balance.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _payments(BuildContext context, StudentAccount account) {
    final payments = account.payments;
    return Panel(
      title: 'Payment history',
      trailing: PanelNote(
        'Immutable ledger · reversals',
        onTap: () => context.go('/finance/reversals'),
      ),
      child: payments.isEmpty
          ? const UiEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments recorded yet',
              message: 'Use Record payment to post the first payment.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTableCard(
                  columns: const [
                    UiColumn('Date', flex: 9),
                    UiColumn('Fee', flex: 11),
                    UiColumn('Amount', flex: 10),
                    UiColumn('Method', flex: 8, hideOnPhone: true),
                    UiColumn('Receipt / reference', flex: 14),
                    UiColumn('State', width: 96),
                    UiColumn('Action', width: 105),
                  ],
                  rows: [
                    for (final p in payments)
                      UiTableRow([
                        UiCellText(formatUiDate(p.paymentDate)),
                        UiCellText(p.feeType ?? 'Fee'),
                        UiCellText(formatMwk(p.amount), bold: true),
                        UiCellText(p.method.replaceAll('_', ' ')),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UiCellText(
                              p.receiptNumber == null
                                  ? '—'
                                  : 'Receipt ${p.receiptNumber}',
                            ),
                            if (p.referenceNumber != null)
                              _sub('Ref ${p.referenceNumber}'),
                            if (p.channelSummary != null)
                              _sub(p.channelSummary!),
                            if (p.reversed && p.reversalReason != null)
                              _sub('Reversed: ${p.reversalReason}'),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: p.reversed
                              ? const StatusPill(
                                  'Reversed',
                                  tone: StatusTone.danger,
                                )
                              : const StatusPill(
                                  'Posted',
                                  tone: StatusTone.success,
                                ),
                        ),
                        p.reversed
                            ? const SizedBox.shrink()
                            : TextButton.icon(
                                onPressed: _reversing.contains(p.paymentId)
                                    ? null
                                    : () => _reversePayment(p),
                                icon: _reversing.contains(p.paymentId)
                                    ? const SizedBox.square(
                                        dimension: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.undo_rounded, size: 17),
                                label: const Text('Reverse'),
                              ),
                      ]),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: UiButton.secondary(
                    'Payment reversals',
                    icon: Icons.undo_outlined,
                    onPressed: () => context.go('/finance/reversals'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sub(String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );

  Widget _adjustments(StudentAccount account) {
    final rows = account.adjustments;
    return Panel(
      title: 'Adjustments',
      trailing: const PanelNote('Discounts, waivers and penalties'),
      child: rows.isEmpty
          ? const UiEmptyState(
              icon: Icons.tune_outlined,
              title: 'No adjustments or waivers',
              message: 'Adjustments need a written reason and approval.',
            )
          : DataTableCard(
              columns: const [
                UiColumn('Date', flex: 9),
                UiColumn('Type', flex: 8),
                UiColumn('Amount', flex: 9),
                UiColumn('Reason', flex: 18),
                UiColumn('Approved by', flex: 10, hideOnPhone: true),
              ],
              rows: [
                for (final a in rows)
                  UiTableRow([
                    UiCellText(formatUiDate(a.createdAt)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: a.amount < 0
                          ? const StatusPill(
                              'Discount',
                              tone: StatusTone.success,
                            )
                          : const StatusPill(
                              'Penalty',
                              tone: StatusTone.warning,
                            ),
                    ),
                    UiCellText(formatMwk(a.amount), bold: true),
                    UiCellText(a.reason),
                    UiCellText(a.approvedByName ?? '—'),
                  ]),
              ],
            ),
    );
  }
}
