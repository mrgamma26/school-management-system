import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_record_list.dart';
import '../../data/finance_records_repository.dart';

final _reversalsProvider = FutureProvider.autoDispose<List<PaymentReversalRow>>(
  (ref) => FinanceRecordsRepository().listReversals(),
);

/// Screen 47 - Payment reversals (read-only).
///
/// Posted payments are never edited; a reversal is a separate record with a
/// mandatory reason. This list is the audit view of those reversals. Access
/// follows the `payment_reversals` RLS policy (Accountant, Administrator and
/// Super User).
class PaymentReversalsPage extends ConsumerWidget {
  const PaymentReversalsPage({super.key});

  void _showDetail(BuildContext context, PaymentReversalRow r) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment reversal'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: DialogDetailList([
              ('Receipt', r.receiptNumber),
              ('Student', r.studentName),
              ('Payment amount', formatMwk(r.amount)),
              ('Payment date', formatUiDate(r.paymentDate)),
              ('Reversed by', r.reversedByName),
              ('Reversed', formatUiDate(r.reversedAt)),
              ('Reason', r.reason),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_reversalsProvider);
    return UiPage(
      children: [
        PageHead(
          kicker: 'Finance',
          title: 'Payment Reversals',
          subtitle:
              'Reversed payments and why. Posted payments are never edited.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_reversalsProvider),
            ),
          ],
        ),
        RecordListView<PaymentReversalRow>(
          data: data,
          onRetry: () => ref.invalidate(_reversalsProvider),
          loadingMessage: 'Loading payment reversals…',
          searchHint: 'Search receipt, student or reason',
          searchText: (r) => '${r.receiptNumber} ${r.studentName} ${r.reason}',
          emptyIcon: Icons.undo_rounded,
          emptyTitle: 'No payments have been reversed',
          header: (items) => AdaptiveGrid(
            columns: 2,
            phoneColumns: 1,
            children: [
              MetricCard(
                icon: Icons.undo_rounded,
                label: 'Reversals',
                value: '${items.length}',
                noteTone: StatusTone.neutral,
              ),
              MetricCard(
                icon: Icons.payments_outlined,
                label: 'Total reversed',
                value: formatMwk(
                  items.fold<double>(0, (sum, r) => sum + r.amount),
                ),
                noteTone: StatusTone.neutral,
              ),
            ],
          ),
          columns: const [
            UiColumn('Receipt', flex: 10),
            UiColumn('Student', flex: 13),
            UiColumn('Amount', flex: 10),
            UiColumn('Reversed by', flex: 11, hideOnPhone: true),
            UiColumn('Reversed', flex: 9, hideOnPhone: true),
            UiColumn('Reason', flex: 14, hideOnPhone: true),
          ],
          rowOf: (r) => UiTableRow([
            UiCellText(r.receiptNumber, bold: true),
            PersonCell(r.studentName),
            UiCellText(formatMwk(r.amount), bold: true),
            UiCellText(r.reversedByName),
            UiCellText(formatUiDate(r.reversedAt)),
            UiCellText(r.reason),
          ], onTap: () => _showDetail(context, r)),
        ),
      ],
    );
  }
}
