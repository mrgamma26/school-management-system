import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/export_service.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_record_list.dart';
import '../../../academics/domain/models/academic_year.dart';
import '../../domain/account_ledger.dart';
import '../../domain/overdue_rules.dart';
import '../finance_account_providers.dart';
import 'student_accounts_page.dart';

/// Overdue Accounts - every student whose outstanding balance is above zero.
///
/// "Overdue" here means an unpaid balance as computed by the database rule
/// (fees - non-reversed payments + adjustments). Fee structures carry no due
/// date, so the due date is defined as the START of the fee's academic period
/// and "Days overdue" is counted from there (blank when unknown). Each row
/// opens the student's account workspace.
class OverdueAccountsPage extends ConsumerStatefulWidget {
  const OverdueAccountsPage({super.key});

  @override
  ConsumerState<OverdueAccountsPage> createState() =>
      _OverdueAccountsPageState();
}

class _OverdueAccountsPageState extends ConsumerState<OverdueAccountsPage> {
  OverdueSort _sort = OverdueSort.balanceHighToLow;

  static String formLabel(String? form) =>
      form == null ? 'No form' : formatFormLevel(form);

  static const _daysTooltip =
      'Counted from the start of the fee period. Fees have no separate due date.';

  Future<void> _printList(
    BuildContext context,
    List<StudentBalanceRow> rows,
  ) async {
    try {
      await ExportService.exportToPdf(
        title: 'Overdue Accounts',
        subtitle: '${rows.length} student(s) with an outstanding balance',
        headers: const [
          'Student',
          'Class',
          'Fees due',
          'Paid',
          'Balance',
          'Days overdue',
          'Last payment',
        ],
        rows: [
          for (final s in rows)
            [
              s.name,
              s.className ?? '—',
              formatMwk(s.feesDue),
              formatMwk(s.paid),
              formatMwk(s.balance),
              daysOverdueLabel(s),
              formatUiDate(s.lastPaymentDate),
            ],
        ],
        footer:
            'Days overdue are counted from the start of the fee period. '
            'Generated on ${DateTime.now().toIso8601String().substring(0, 10)}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create the list: ${friendlyError(e)}'),
          ),
        );
      }
    }
  }

  static String daysOverdueLabel(StudentBalanceRow s, [DateTime? today]) {
    final days = daysOverdue(s.dueDate, today ?? DateTime.now());
    return days == null ? '' : '$days';
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(balanceOverviewProvider);
    final today = DateTime.now();
    final owing = all.whenData(
      (rows) => sortOverdueRows(
        [
          for (final r in rows)
            if (r.owes) r,
        ],
        _sort,
        today,
      ),
    );
    final loaded = owing.value;
    final forms = <String>{
      for (final r in loaded ?? const <StudentBalanceRow>[]) formLabel(r.form),
    }.toList()..sort();
    return UiPage(
      children: [
        PageHead(
          kicker: 'Finance',
          title: 'Overdue Accounts',
          subtitle:
              'Students with an outstanding balance. Days overdue are counted from the start of the fee period. Open a row to follow up in the account workspace.',
          actions: [
            UiButton.secondary(
              'Payment arrangements',
              icon: Icons.event_repeat_outlined,
              onPressed: () => context.go('/finance/arrangements'),
            ),
            UiButton.secondary(
              'Print list',
              icon: Icons.print_outlined,
              onPressed: loaded == null || loaded.isEmpty
                  ? null
                  : () => _printList(context, loaded),
            ),
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(balanceOverviewProvider),
            ),
          ],
        ),
        RecordListView<StudentBalanceRow>(
          data: owing,
          onRetry: () => ref.invalidate(balanceOverviewProvider),
          loadingMessage: 'Calculating balances…',
          searchHint: 'Search by student name or class',
          searchText: (s) => '${s.name} ${s.className ?? ''}',
          filters: ['All forms', ...forms],
          matchesFilter: (s, f) => formLabel(s.form) == f,
          emptyIcon: Icons.verified_outlined,
          emptyTitle: 'No overdue accounts',
          emptyMessage: 'Every student with fees is paid up.',
          header: (items) {
            final total = items.fold<double>(0, (t, s) => t + s.balance);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdaptiveGrid(
                  columns: 2,
                  phoneColumns: 1,
                  children: [
                    MetricCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Accounts with a balance',
                      value: '${items.length}',
                      noteTone: StatusTone.warning,
                    ),
                    MetricCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total outstanding',
                      value: formatMwk(total),
                      noteTone: StatusTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Sort by',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    for (final option in OverdueSort.values)
                      FilterChipBox(
                        option.label,
                        selected: option == _sort,
                        onTap: () => setState(() => _sort = option),
                      ),
                  ],
                ),
              ],
            );
          },
          columns: const [
            UiColumn('Student', flex: 16),
            UiColumn('Class', flex: 9, hideOnPhone: true),
            UiColumn('Fees due', flex: 10, hideOnPhone: true),
            UiColumn('Balance', flex: 10),
            UiColumn('Days overdue', flex: 9),
            UiColumn('Last payment', flex: 10, hideOnPhone: true),
            UiColumn('', width: 130),
          ],
          rowOf: (s) => UiTableRow([
            PersonCell(s.name, subtitle: formLabel(s.form)),
            UiCellText(s.className ?? '—'),
            UiCellText(formatMwk(s.feesDue)),
            UiCellText(formatMwk(s.balance), bold: true),
            Tooltip(
              message: _daysTooltip,
              child: UiCellText(daysOverdueLabel(s, today)),
            ),
            UiCellText(
              s.lastPaymentDate == null
                  ? 'No payment yet'
                  : formatUiDate(s.lastPaymentDate),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: UiButton.secondary(
                'Open account',
                onPressed: () =>
                    openStudentAccount(context, s.studentId, s.name),
              ),
            ),
          ], onTap: () => openStudentAccount(context, s.studentId, s.name)),
        ),
        const SizedBox(height: 14),
        const InlineGuide(
          title: 'Follow-up:',
          text:
              'Reminder emails and printed notices are not available yet because the app has no email or notice path for fee reminders. Payment arrangements can be viewed read-only from the button above.',
        ),
      ],
    );
  }
}
