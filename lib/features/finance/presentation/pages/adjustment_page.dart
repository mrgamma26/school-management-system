import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Adjustments\n${widget.studentName}'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(_adjustmentsProvider(widget.studentId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAdjustment,
        icon: const Icon(Icons.add),
        label: const Text('Add Adjustment'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No adjustments recorded.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = items[i];
              final isDiscount = a.isDiscount;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDiscount
                      ? Colors.blue.shade50
                      : Colors.red.shade50,
                  child: Icon(
                    isDiscount ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isDiscount ? Colors.blue : Colors.red,
                  ),
                ),
                title: Text(
                  '${isDiscount ? 'Discount' : 'Penalty'}: '
                  'MWK ${a.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isDiscount ? Colors.blue : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${a.reason}\n'
                  '${a.createdAt.toIso8601String().substring(0, 10)}'
                  '${a.approvedByName != null ? '  ·  ${a.approvedByName}' : ''}',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
