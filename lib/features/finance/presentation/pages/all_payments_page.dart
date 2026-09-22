import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/payment.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/academic_year.dart';

final _allPaymentsProvider = FutureProvider.family<List<Payment>, String>((
  ref,
  yearId,
) {
  return FinanceRepository().allPayments(academicYearId: yearId);
});

final _yearsForPaymentsProvider = FutureProvider<List<AcademicYear>>((ref) {
  return AcademicRepository().listAcademicYears();
});

class AllPaymentsPage extends ConsumerStatefulWidget {
  const AllPaymentsPage({super.key});

  @override
  ConsumerState<AllPaymentsPage> createState() => _AllPaymentsPageState();
}

class _AllPaymentsPageState extends ConsumerState<AllPaymentsPage> {
  AcademicYear? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_yearsForPaymentsProvider);
    final role = ref.watch(authProvider).user?.roleName ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Payments'),
        actions: [
          HomeButton(roleName: role),
          if (_selectedYear != null)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () =>
                  ref.invalidate(_allPaymentsProvider(_selectedYear!.id)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Year selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: yearsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ErrorState(error: e),
              data: (years) {
                if (years.isEmpty) {
                  return const EmptyState(
                    icon: Icons.calendar_today_outlined,
                    title: 'No academic years found',
                  );
                }
                // Auto-select first year if none selected yet
                if (_selectedYear == null && years.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedYear = years.first);
                  });
                }
                return DropdownButtonFormField<AcademicYear>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: years
                      .map(
                        (y) => DropdownMenuItem(value: y, child: Text(y.label)),
                      )
                      .toList(),
                  onChanged: (y) => setState(() => _selectedYear = y),
                );
              },
            ),
          ),

          // Payments
          if (_selectedYear == null)
            const Expanded(
              child: EmptyState(
                icon: Icons.payments_outlined,
                title: 'Select a year',
                subtitle: 'Choose an academic year to view payments.',
              ),
            )
          else
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final paymentsAsync = ref.watch(
                    _allPaymentsProvider(_selectedYear!.id),
                  );

                  return paymentsAsync.when(
                    loading: () =>
                        const LoadingState(message: 'Loading payments...'),
                    error: (e, _) => ErrorState(
                      error: e,
                      onRetry: () => ref.invalidate(
                        _allPaymentsProvider(_selectedYear!.id),
                      ),
                    ),
                    data: (payments) {
                      if (payments.isEmpty) {
                        return const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No payments recorded',
                          subtitle:
                              'No payments have been recorded for this academic year.',
                        );
                      }

                      final total = payments.fold<double>(
                        0.0,
                        (s, p) => s + p.amount,
                      );

                      return Column(
                        children: [
                          // Summary banner
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${payments.length} payment${payments.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'MWK ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              itemCount: payments.length,
                              itemBuilder: (_, i) {
                                final p = payments[i];
                                final dateStr = p.paymentDate
                                    .toIso8601String()
                                    .substring(0, 10);
                                return Card(
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.payments,
                                        color: AppColors.success,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      'MWK ${p.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.studentName ?? 'Unknown Student',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              p.feeType ?? 'Unknown Fee',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurface.withValues(
                                                  alpha: 0.55,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '  -  ${p.method}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurface.withValues(
                                                  alpha: 0.55,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        if (p.receiptNumber != null)
                                          Text(
                                            '# ${p.receiptNumber}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: cs.onSurface.withValues(
                                                alpha: 0.4,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
