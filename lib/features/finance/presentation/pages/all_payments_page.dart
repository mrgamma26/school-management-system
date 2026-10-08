import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/payment.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/academic_year.dart';
import '../../../academics/domain/models/class_model.dart';

final _allPaymentsProvider =
    FutureProvider.family<
      List<Payment>,
      ({String yearId, String? classId, String? searchQuery})
    >((ref, params) {
      return FinanceRepository().allPayments(
        academicYearId: params.yearId,
        classId: params.classId,
        searchQuery: params.searchQuery,
      );
    });

final _yearsForPaymentsProvider = FutureProvider<List<AcademicYear>>((ref) {
  return AcademicRepository().listAcademicYears();
});

final _classesProvider = FutureProvider<List<ClassModel>>((ref) {
  return AcademicRepository().listClasses();
});

class AllPaymentsPage extends ConsumerStatefulWidget {
  const AllPaymentsPage({super.key});

  @override
  ConsumerState<AllPaymentsPage> createState() => _AllPaymentsPageState();
}

class _AllPaymentsPageState extends ConsumerState<AllPaymentsPage> {
  AcademicYear? _selectedYear;
  ClassModel? _selectedClass;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_yearsForPaymentsProvider);
    final classesAsync = ref.watch(_classesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Payments'),
        actions: [
          if (_selectedYear != null)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () {
                ref.invalidate(
                  _allPaymentsProvider((
                    yearId: _selectedYear!.id,
                    classId: _selectedClass?.id,
                    searchQuery: _searchQuery,
                  )),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Year selector + Search + Class filter
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
                return Column(
                  children: [
                    // Academic year dropdown
                    DropdownButtonFormField<AcademicYear>(
                      initialValue: _selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      items: years
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.label),
                            ),
                          )
                          .toList(),
                      onChanged: (y) => setState(() => _selectedYear = y),
                    ),
                    const SizedBox(height: 12),
                    // Search field
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search by student name or ID',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: 12),
                    // Class filter dropdown
                    classesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading classes: $e'),
                      data: (classes) {
                        return DropdownButtonFormField<ClassModel?>(
                          initialValue: _selectedClass,
                          decoration: const InputDecoration(
                            labelText: 'Filter by class (optional)',
                            prefixIcon: Icon(Icons.class_),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All classes'),
                            ),
                            ...classes.map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.classroomName),
                              ),
                            ),
                          ],
                          onChanged: (c) => setState(() => _selectedClass = c),
                        );
                      },
                    ),
                  ],
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
                    _allPaymentsProvider((
                      yearId: _selectedYear!.id,
                      classId: _selectedClass?.id,
                      searchQuery: _searchQuery,
                    )),
                  );

                  return paymentsAsync.when(
                    loading: () =>
                        const LoadingState(message: 'Loading payments...'),
                    error: (e, _) => ErrorState(
                      error: e,
                      onRetry: () {
                        ref.invalidate(
                          _allPaymentsProvider((
                            yearId: _selectedYear!.id,
                            classId: _selectedClass?.id,
                            searchQuery: _searchQuery,
                          )),
                        );
                      },
                    ),
                    data: (payments) {
                      if (payments.isEmpty) {
                        return const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No payments recorded',
                          subtitle:
                              'No payments match your filters for this academic year.',
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
                                        if (p.referenceNumber != null)
                                          Text(
                                            'Reference: ${p.referenceNumber}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurface.withValues(
                                                alpha: 0.55,
                                              ),
                                            ),
                                          ),
                                        if (p.channelSummary != null)
                                          Text(
                                            p.channelSummary!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurface.withValues(
                                                alpha: 0.55,
                                              ),
                                            ),
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
                                    onTap: () {
                                      // View payment details or student account
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Payment: ${p.paymentId}',
                                          ),
                                        ),
                                      );
                                    },
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
