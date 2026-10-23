import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/rpc_error.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_record_list.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/finance_records_repository.dart';

final _arrangementsProvider =
    FutureProvider.autoDispose<List<PaymentArrangementRow>>(
      (ref) => FinanceRecordsRepository().listArrangements(),
    );

StatusTone _toneFor(String status) => switch (status) {
  'ACTIVE' => StatusTone.info,
  'COMPLETED' => StatusTone.success,
  'DEFAULTED' => StatusTone.danger,
  'PAID' => StatusTone.success,
  'MISSED' => StatusTone.danger,
  'PENDING' => StatusTone.warning,
  _ => StatusTone.neutral,
};

String _labelFor(String status) =>
    status.isEmpty ? '—' : status[0] + status.substring(1).toLowerCase();

/// Screen 45 - Payment arrangements.
///
/// Instalment plans agreed for outstanding balances, with the progress of each
/// instalment. The Accountant can agree a new plan; everyone else with access
/// reads only (the `payment_arrangements` RLS policy and the
/// `create_payment_arrangement` function enforce this).
class PaymentArrangementsPage extends ConsumerWidget {
  const PaymentArrangementsPage({super.key});

  void _showDetail(BuildContext context, PaymentArrangementRow a) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arrangement - ${a.studentName}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DialogDetailList([
                  ('Total agreed', formatMwk(a.totalAmount)),
                  ('Payments received', formatMwk(a.paidAmount)),
                  ('Remaining on plan', formatMwk(a.remainingAmount)),
                  ('Status', _labelFor(a.status)),
                  ('Next follow-up', formatUiDate(a.nextFollowUp)),
                  ('Created', formatUiDate(a.createdAt)),
                  if (a.notes != null && a.notes!.trim().isNotEmpty)
                    ('Notes', a.notes!),
                ]),
                const SizedBox(height: 14),
                const FieldLabel('Instalments'),
                if (a.installments.isEmpty)
                  const Text('No instalments recorded.')
                else
                  for (final i in a.installments)
                    DetailLine(
                      formatUiDate(i.dueDate),
                      formatMwk(i.amount),
                      trailing: StatusPill(
                        _labelFor(i.status),
                        tone: _toneFor(i.status),
                      ),
                    ),
              ],
            ),
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

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewArrangementDialog(),
    );
    if (created == true) {
      ref.invalidate(_arrangementsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment arrangement created.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_arrangementsProvider);
    final role = ref.watch(authProvider).user?.roleName ?? '';
    final canCreate = canRecordStudentPayments(role);
    return UiPage(
      children: [
        PageHead(
          kicker: 'Finance',
          title: 'Payment Arrangements',
          subtitle: 'Instalment plans agreed for outstanding balances.',
          actions: [
            if (canCreate)
              UiButton(
                'New arrangement',
                icon: Icons.add_rounded,
                onPressed: () => _create(context, ref),
              ),
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_arrangementsProvider),
            ),
          ],
        ),
        RecordListView<PaymentArrangementRow>(
          data: data,
          onRetry: () => ref.invalidate(_arrangementsProvider),
          loadingMessage: 'Loading payment arrangements…',
          searchHint: 'Search student',
          searchText: (a) => a.studentName,
          filters: const [
            'All',
            'Active',
            'Completed',
            'Defaulted',
            'Cancelled',
          ],
          matchesFilter: (a, f) => _labelFor(a.status) == f,
          emptyIcon: Icons.event_repeat_outlined,
          emptyTitle: 'No payment arrangements yet',
          emptyMessage: canCreate
              ? 'Press New arrangement to agree an instalment plan.'
              : 'Arrangements appear here once the Accountant agrees a plan.',
          header: (items) => AdaptiveGrid(
            columns: 3,
            phoneColumns: 1,
            children: [
              MetricCard(
                icon: Icons.event_repeat_outlined,
                label: 'Active plans',
                value: '${items.where((a) => a.status == 'ACTIVE').length}',
                noteTone: StatusTone.neutral,
              ),
              MetricCard(
                icon: Icons.warning_amber_rounded,
                label: 'Defaulted',
                value: '${items.where((a) => a.status == 'DEFAULTED').length}',
                noteTone: StatusTone.danger,
              ),
              MetricCard(
                icon: Icons.task_alt_rounded,
                label: 'Completed',
                value: '${items.where((a) => a.status == 'COMPLETED').length}',
                noteTone: StatusTone.neutral,
              ),
            ],
          ),
          columns: const [
            UiColumn('Student', flex: 14),
            UiColumn('Total', flex: 10),
            UiColumn('Instalments', flex: 8, hideOnPhone: true),
            UiColumn('Next follow-up', flex: 10, hideOnPhone: true),
            UiColumn('Status', width: 100),
          ],
          rowOf: (a) => UiTableRow([
            PersonCell(a.studentName),
            UiCellText(formatMwk(a.totalAmount), bold: true),
            UiCellText(
              '${formatMwk(a.paidAmount)} received · '
              '${a.paidInstallments} of ${a.installments.length} due dates covered',
            ),
            UiCellText(formatUiDate(a.nextFollowUp)),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(_labelFor(a.status), tone: _toneFor(a.status)),
            ),
          ], onTap: () => _showDetail(context, a)),
        ),
      ],
    );
  }
}

class _InstalmentDraft {
  DateTime? dueDate;
  final amount = TextEditingController();
}

/// Accountant dialog: pick a student, list the instalments (due date and
/// amount) and save through `create_payment_arrangement`.
class _NewArrangementDialog extends StatefulWidget {
  const _NewArrangementDialog();

  @override
  State<_NewArrangementDialog> createState() => _NewArrangementDialogState();
}

class _NewArrangementDialogState extends State<_NewArrangementDialog> {
  final _repo = FinanceRecordsRepository();
  final _notes = TextEditingController();
  final _rows = [_InstalmentDraft(), _InstalmentDraft()];
  List<ArrangementStudent> _students = const [];
  String? _studentId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo
        .listArrangementStudents()
        .then((list) {
          if (mounted) {
            setState(() {
              _students = list;
              _loading = false;
            });
          }
        })
        .catchError((Object e) {
          if (mounted) {
            setState(() {
              _error = friendlyError(e);
              _loading = false;
            });
          }
        });
  }

  Future<void> _pickDate(_InstalmentDraft row) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: row.dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => row.dueDate = picked);
  }

  double get _total => _rows.fold(
    0,
    (sum, r) => sum + (double.tryParse(r.amount.text.trim()) ?? 0),
  );

  Future<void> _save() async {
    if (_studentId == null) {
      setState(() => _error = 'Choose the student.');
      return;
    }
    final items = <({DateTime dueDate, double amount})>[];
    for (final r in _rows) {
      final amount = double.tryParse(r.amount.text.trim());
      if (r.dueDate == null || amount == null || amount <= 0) {
        setState(
          () => _error =
              'Every instalment needs a due date and an amount above zero.',
        );
        return;
      }
      items.add((dueDate: r.dueDate!, amount: amount));
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.createArrangement(
        studentId: _studentId!,
        installments: items,
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = rpcErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New payment arrangement'),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Student *'),
                      items: [
                        for (final s in _students)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _studentId = v),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Instalments'),
                    for (var i = 0; i < _rows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(_rows[i]),
                                child: Text(
                                  _rows[i].dueDate == null
                                      ? 'Due date'
                                      : formatUiDate(_rows[i].dueDate),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _rows[i].amount,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Amount (MWK)',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove instalment',
                              onPressed: _rows.length > 1
                                  ? () => setState(() => _rows.removeAt(i))
                                  : null,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _rows.add(_InstalmentDraft())),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add instalment'),
                      ),
                    ),
                    Text(
                      'Total agreed: ${formatMwk(_total)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading || _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Create arrangement'),
        ),
      ],
    );
  }
}
