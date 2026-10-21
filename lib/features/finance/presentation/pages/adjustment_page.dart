import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/financial_adjustment.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/services/audit_service.dart';

final _adjustmentsProvider =
    FutureProvider.family<List<FinancialAdjustment>, String>(
      (ref, studentId) => FinanceRepository().adjustmentsForStudent(studentId),
    );

/// Lists financial adjustments for a student and allows adding new ones.
class AdjustmentPage extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;

  const AdjustmentPage({
    required this.studentId,
    required this.studentName,
    super.key,
  });

  @override
  ConsumerState<AdjustmentPage> createState() => _AdjustmentPageState();
}

class _AdjustmentPageState extends ConsumerState<AdjustmentPage> {
  Future<void> _addAdjustment() async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String type = 'DISCOUNT'; // DISCOUNT or PENALTY

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Adjustment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'DISCOUNT',
                      child: Text('Discount / Waiver'),
                    ),
                    DropdownMenuItem(
                      value: 'PENALTY',
                      child: Text('Penalty / Charge'),
                    ),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount (MWK)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final raw = double.tryParse(amountCtrl.text.trim());
                if (raw == null || raw <= 0) return;
                if (reasonCtrl.text.trim().isEmpty) return;

                // Discounts are stored as negative values
                final amount = type == 'DISCOUNT' ? -raw : raw;

                try {
                  final currentUser = ref.read(authProvider).user!;
                  final staffId = await FinanceRepository().getStaffIdForUser(
                    currentUser.userId,
                  );

                  await FinanceRepository().createAdjustment(
                    studentId: widget.studentId,
                    staffId: staffId,
                    amount: amount,
                    reason: reasonCtrl.text.trim(),
                  );

                  await AuditService().log(
                    userId: currentUser.userId,
                    action: 'FINANCIAL_ADJUSTMENT_CREATED',
                    tableName: 'financialadjustment',
                    newValue: {
                      'studentid': widget.studentId,
                      'amount': amount,
                      'reason': reasonCtrl.text.trim(),
                    },
                    actorRole: currentUser.roleName,
                  );

                  if (ctx.mounted) Navigator.pop(ctx, true);
                  ref.invalidate(_adjustmentsProvider(widget.studentId));
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    amountCtrl.dispose();
    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adjustmentsProvider(widget.studentId));

    return UiPage(
      children: [
        PageHead(
          kicker: 'Finance',
          title: 'Adjustments',
          subtitle: widget.studentName,
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(_adjustmentsProvider(widget.studentId)),
            ),
            UiButton(
              'Add Adjustment',
              icon: Icons.add_rounded,
              onPressed: _addAdjustment,
            ),
          ],
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading adjustments…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () =>
                ref.invalidate(_adjustmentsProvider(widget.studentId)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.tune_rounded,
                  title: 'No adjustments recorded',
                ),
              );
            }
            return DataTableCard(
              columns: const [
                UiColumn('Type', width: 110),
                UiColumn('Amount', flex: 10),
                UiColumn('Reason', flex: 18),
                UiColumn('Date', flex: 10, hideOnPhone: true),
                UiColumn('Approved by', flex: 12, hideOnPhone: true),
              ],
              rows: [
                for (final a in items)
                  UiTableRow([
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(
                        a.isDiscount ? 'Discount' : 'Penalty',
                        tone: a.isDiscount
                            ? StatusTone.info
                            : StatusTone.warning,
                      ),
                    ),
                    UiCellText(formatMwk(a.amount.abs()), bold: true),
                    UiCellText(a.reason),
                    UiCellText(formatUiDate(a.createdAt)),
                    UiCellText(a.approvedByName ?? '—'),
                  ]),
              ],
            );
          },
        ),
      ],
    );
  }
}
