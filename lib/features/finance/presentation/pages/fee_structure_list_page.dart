import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/can.dart';
import '../../../../widgets/ui_kit.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/fee_structure.dart';

final _feeStructuresProvider =
    FutureProvider.family<List<FeeStructure>, String>((ref, yearId) {
      return FinanceRepository().listFeeStructures();
    });

/// Screen 37 - Fee structures: school-wide fees by academic year and term.
class FeeStructureListPage extends ConsumerStatefulWidget {
  final String academicYearId;
  final String academicYearLabel;

  const FeeStructureListPage({
    required this.academicYearId,
    required this.academicYearLabel,
    super.key,
  });

  @override
  ConsumerState<FeeStructureListPage> createState() =>
      _FeeStructureListPageState();
}

class _FeeStructureListPageState extends ConsumerState<FeeStructureListPage> {
  Future<void> _delete(FeeStructure f) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Fee'),
        content: Text(
          'Delete ${f.feeType}? Existing payments using this fee must be removed first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FinanceRepository().deleteFeeStructure(f.feeStructureId);
      ref.invalidate(_feeStructuresProvider(widget.academicYearId));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_feeStructuresProvider(widget.academicYearId));

    return UiPage(
      children: [
        PageHead(
          kicker: 'Finance',
          title: 'Fee Structures',
          subtitle: 'School-wide fees by academic year and term.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(_feeStructuresProvider(widget.academicYearId)),
            ),
            Can(
              permission: 'finance:manage_structures',
              child: UiButton(
                'Add Fee',
                icon: Icons.add_rounded,
                onPressed: () async {
                  await context.push<bool>(
                    '/finance/fees/${widget.academicYearId}/new',
                  );
                  if (mounted) {
                    ref.invalidate(
                      _feeStructuresProvider(widget.academicYearId),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading fee structures…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () =>
                ref.invalidate(_feeStructuresProvider(widget.academicYearId)),
          ),
          data: (fees) {
            if (fees.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.price_change_outlined,
                  title: 'No fee structures yet',
                  message:
                      'Define school-wide fees for an academic year and term.',
                ),
              );
            }
            final total = fees.fold<double>(0, (s, f) => s + f.amount);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdaptiveGrid(
                  columns: 2,
                  phoneColumns: 2,
                  children: [
                    MetricCard(
                      icon: Icons.receipt_long_outlined,
                      label: 'Fee types',
                      value: '${fees.length}',
                      note: 'Defined fee items',
                      noteTone: StatusTone.neutral,
                    ),
                    MetricCard(
                      icon: Icons.payments_outlined,
                      label: 'Total per learner',
                      value: formatMwk(total),
                      note: 'Sum of all fee items',
                      noteTone: StatusTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DataTableCard(
                  columns: const [
                    UiColumn('Fee item', flex: 14),
                    UiColumn('Period', flex: 12, hideOnPhone: true),
                    UiColumn('Amount', flex: 11),
                    UiColumn('', width: 84),
                  ],
                  rows: [
                    for (final f in fees)
                      UiTableRow([
                        PersonCell(f.feeType),
                        UiCellText(f.academicYearLabel ?? '—'),
                        UiCellText(formatMwk(f.amount), bold: true),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Can(
                              permission: 'finance:manage_structures',
                              child: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit',
                                onPressed: () async {
                                  await context.push<bool>(
                                    '/finance/fees/${widget.academicYearId}/${f.feeStructureId}/edit',
                                    extra: f,
                                  );
                                  if (mounted) {
                                    ref.invalidate(
                                      _feeStructuresProvider(
                                        widget.academicYearId,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            Can(
                              permission: 'finance:manage_structures',
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete',
                                onPressed: () => _delete(f),
                              ),
                            ),
                          ],
                        ),
                      ]),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
