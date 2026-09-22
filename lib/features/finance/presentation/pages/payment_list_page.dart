import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/payment.dart';
import 'record_payment_page.dart';

final _paymentListProvider = FutureProvider.family<List<Payment>, String>((
  ref,
  studentId,
) {
  return FinanceRepository().paymentsForStudent(studentId);
});

/// Shows all payments for one student with a running total.
class PaymentListPage extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const PaymentListPage({
    required this.studentId,
    required this.studentName,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_paymentListProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Payments\n$studentName'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_paymentListProvider(studentId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => RecordPaymentPage(
                studentId: studentId,
                studentName: studentName,
              ),
            ),
          );
          ref.invalidate(_paymentListProvider(studentId));
        },
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (payments) {
          if (payments.isEmpty) {
            return const Center(child: Text('No payments recorded yet.'));
          }

          final total = payments.fold<double>(0.0, (sum, p) => sum + p.amount);

          return Column(
            children: [
              _SummaryBar(total: total),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: payments.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = payments[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: const Icon(Icons.payments, color: Colors.green),
                      ),
                      title: Text(
                        'MWK ${p.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${p.feeType ?? ''}  ·  '
                        '${p.paymentDate.toIso8601String().substring(0, 10)}\n'
                        '${p.method}'
                        '${p.receiptNumber != null ? '  ·  Receipt: ${p.receiptNumber}' : ''}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final double total;
  const _SummaryBar({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.green.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Paid',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'MWK ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
