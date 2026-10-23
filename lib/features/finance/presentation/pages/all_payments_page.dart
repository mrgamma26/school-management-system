import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/academic_year.dart';
import '../../../academics/domain/models/class_model.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/payment.dart';

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

/// Posted payments across the school for an academic year.
class AllPaymentsPage extends ConsumerStatefulWidget {
  const AllPaymentsPage({super.key});

  @override
  ConsumerState<AllPaymentsPage> createState() => _AllPaymentsPageState();
}

class _AllPaymentsPageState extends ConsumerState<AllPaymentsPage> {
  static const _pageSize = 25;

  AcademicYear? _selectedYear;
  ClassModel? _selectedClass;
  String _searchQuery = '';
  int _page = 0;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ({String yearId, String? classId, String? searchQuery}) get _params => (
    yearId: _selectedYear!.id,
    classId: _selectedClass?.id,
    searchQuery: _searchQuery,
  );

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_yearsForPaymentsProvider);
    final classesAsync = ref.watch(_classesProvider);

    return UiPage(
      children: [
        PageHead(
          kicker: 'Finance',
          title: 'Payments',
          subtitle:
              'Posted payments, receipts and references for a school year.',
          actions: [
            if (_selectedYear != null)
              UiButton.secondary(
                'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(_allPaymentsProvider(_params)),
              ),
          ],
        ),
        yearsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_yearsForPaymentsProvider),
          ),
          data: (years) {
            if (years.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No academic years found',
                ),
              );
            }
            // Auto-select first year if none selected yet
            if (_selectedYear == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedYear = years.first);
              });
            }
            return UiCard(
              padding: const EdgeInsets.all(12),
              child: FieldGrid(
                children: [
                  UiField(
                    label: 'Academic year',
                    child: DropdownButtonFormField<AcademicYear>(
                      initialValue: _selectedYear,
                      items: years
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.label),
                            ),
                          )
                          .toList(),
                      onChanged: (y) => setState(() {
                        _selectedYear = y;
                        _page = 0;
                      }),
                    ),
                  ),
                  UiField(
                    label: 'Class (optional)',
                    child: classesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading classes: $e'),
                      data: (classes) => DropdownButtonFormField<ClassModel?>(
                        initialValue: _selectedClass,
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
                        onChanged: (c) => setState(() {
                          _selectedClass = c;
                          _page = 0;
                        }),
                      ),
                    ),
                  ),
                  FullWidth(
                    child: UiField(
                      label: 'Search by student name or ID',
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _page = 0;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => setState(() {
                          _searchQuery = value;
                          _page = 0;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        if (_selectedYear == null)
          const UiCard(
            child: UiEmptyState(
              icon: Icons.payments_outlined,
              title: 'Select a year',
              message: 'Choose an academic year to view payments.',
            ),
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final paymentsAsync = ref.watch(_allPaymentsProvider(_params));
              return paymentsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: LoadingState(message: 'Loading payments…'),
                ),
                error: (e, _) => ErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(_allPaymentsProvider(_params)),
                ),
                data: (payments) {
                  if (payments.isEmpty) {
                    return const UiCard(
                      child: UiEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No payments recorded',
                        message:
                            'No payments match your filters for this academic year.',
                      ),
                    );
                  }
                  final total = payments.fold<double>(
                    0.0,
                    (s, p) => s + p.amount,
                  );
                  final pageCount = (payments.length / _pageSize).ceil();
                  final page = _page.clamp(0, pageCount - 1);
                  final visible = PagerBar.slice(payments, page, _pageSize);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdaptiveGrid(
                        columns: 2,
                        phoneColumns: 2,
                        children: [
                          MetricCard(
                            icon: Icons.receipt_long_outlined,
                            label: 'Payments',
                            value: '${payments.length}',
                            note: 'Matching your filters',
                            noteTone: StatusTone.neutral,
                          ),
                          MetricCard(
                            icon: Icons.payments_outlined,
                            label: 'Total collected',
                            value: formatMwk(total),
                            note: 'Sum of the payments listed',
                            noteTone: StatusTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DataTableCard(
                        columns: const [
                          UiColumn('Date', flex: 8),
                          UiColumn('Student', flex: 14),
                          UiColumn('Fee', flex: 10, hideOnPhone: true),
                          UiColumn('Amount', flex: 10),
                          UiColumn('Method', flex: 8, hideOnPhone: true),
                          UiColumn('Receipt', flex: 9, hideOnPhone: true),
                        ],
                        rows: [
                          for (final p in visible)
                            UiTableRow([
                              UiCellText(formatUiDate(p.paymentDate)),
                              PersonCell(
                                p.studentName ?? 'Unknown student',
                                subtitle: p.referenceNumber == null
                                    ? p.channelSummary
                                    : 'Ref ${p.referenceNumber}',
                              ),
                              UiCellText(p.feeType ?? 'Unknown fee'),
                              UiCellText(formatMwk(p.amount), bold: true),
                              UiCellText(p.method.replaceAll('_', ' ')),
                              UiCellText(p.receiptNumber ?? '—'),
                            ]),
                        ],
                      ),
                      PagerBar(
                        total: payments.length,
                        page: page,
                        pageSize: _pageSize,
                        onPage: (p) => setState(() => _page = p),
                      ),
                    ],
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
