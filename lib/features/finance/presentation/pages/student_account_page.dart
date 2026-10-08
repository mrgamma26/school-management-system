import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/payment.dart';

final _studentAccountPaymentsProvider =
    FutureProvider.family<List<Payment>, String>((ref, studentId) {
      return FinanceRepository().paymentsForStudent(studentId);
    });

/// Student financial account overview — entry point for the accountant
/// when they tap a student. Shows payment entry and the student's history.
class StudentAccountPage extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const StudentAccountPage({
    required this.studentId,
    required this.studentName,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(studentName)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _tile(
            context,
            icon: Icons.payments,
            color: Colors.green,
            title: 'Record Payment',
            subtitle: 'Add a fee payment for this student',
            onTap: () async {
              final saved = await context.push<bool>(
                '/finance/students/$studentId/pay'
                '?name=${Uri.encodeComponent(studentName)}',
              );
              if (saved == true) {
                ref.invalidate(_studentAccountPaymentsProvider(studentId));
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Payment History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ref
              .watch(_studentAccountPaymentsProvider(studentId))
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not load payment history: $error'),
                  ),
                ),
                data: (payments) => payments.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No payments recorded yet.'),
                        ),
                      )
                    : Column(
                        children: payments
                            .map(
                              (payment) => Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.receipt_long),
                                  ),
                                  title: Text(
                                    '${payment.feeType ?? 'Fee'} · '
                                    'MWK ${payment.amount.toStringAsFixed(2)}',
                                  ),
                                  subtitle: Text(
                                    '${payment.paymentDate.toIso8601String().substring(0, 10)}'
                                    ' · ${payment.method}'
                                    '${payment.receiptNumber == null ? '' : ' · Receipt ${payment.receiptNumber}'}'
                                    '${payment.referenceNumber == null ? '' : '\nReference ${payment.referenceNumber}'}'
                                    '${payment.channelSummary == null ? '' : '\n${payment.channelSummary}'}',
                                  ),
                                  isThreeLine:
                                      payment.referenceNumber != null ||
                                      payment.channelSummary != null,
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
