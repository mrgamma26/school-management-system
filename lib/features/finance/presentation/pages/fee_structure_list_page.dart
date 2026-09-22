import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/fee_structure.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'fee_structure_form_page.dart';

final _feeStructuresProvider =
    FutureProvider.family<List<FeeStructure>, String>((ref, yearId) {
      return FinanceRepository().listFeeStructures(yearId);
    });

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
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_feeStructuresProvider(widget.academicYearId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fee Structures'),
            Text(
              widget.academicYearLabel,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () =>
                ref.invalidate(_feeStructuresProvider(widget.academicYearId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  FeeStructureFormPage(academicYearId: widget.academicYearId),
            ),
          );
          if (mounted) {
            ref.invalidate(_feeStructuresProvider(widget.academicYearId));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Fee'),
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading fee structures…'),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () =>
              ref.invalidate(_feeStructuresProvider(widget.academicYearId)),
        ),
        data: (fees) {
          if (fees.isEmpty) {
            return EmptyState(
              icon: Icons.price_change_outlined,
              title: 'No fee structures yet',
              subtitle: 'Define fees for ${widget.academicYearLabel}.',
              action: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeeStructureFormPage(
                        academicYearId: widget.academicYearId,
                      ),
                    ),
                  );
                  if (mounted) {
                    ref.invalidate(
                      _feeStructuresProvider(widget.academicYearId),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Fee'),
              ),
            );
          }

          // Total banner
          final total = fees.fold<double>(0, (s, f) => s + f.amount);

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                      '${fees.length} fee type${fees.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Total MWK ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: fees.length,
                  itemBuilder: (_, i) {
                    final f = fees[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: AppColors.warning,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          f.feeType,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: f.className != null
                            ? Text(
                                f.className!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'MWK ${f.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit',
                              onPressed: () async {
                                await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FeeStructureFormPage(
                                      academicYearId: widget.academicYearId,
                                      existing: f,
                                    ),
                                  ),
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
      ),
    );
  }
}
