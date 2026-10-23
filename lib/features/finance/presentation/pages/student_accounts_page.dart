import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_record_list.dart';
import '../../domain/account_ledger.dart';
import '../finance_account_providers.dart';

/// Opens the account workspace of [studentId].
void openStudentAccount(BuildContext context, String studentId, String name) {
  context.go(
    '/finance/students/$studentId/account?name=${Uri.encodeComponent(name)}',
  );
}

/// Student Accounts - search for a learner and open their account workspace.
///
/// Balances come from [balanceOverviewProvider], which applies the same rule
/// as the database's `private.student_outstanding_balance`.
class StudentAccountsPage extends ConsumerWidget {
  const StudentAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(balanceOverviewProvider);
    return UiPage(
      children: [
        PageHead(
          kicker: 'Finance',
          title: 'Student Accounts',
          subtitle:
              'Search a student to see obligations, payments, adjustments and balance, and to record a payment.',
          actions: [
            UiButton.secondary(
              'Overdue accounts',
              icon: Icons.warning_amber_rounded,
              onPressed: () => context.go('/finance/overdue'),
            ),
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(balanceOverviewProvider),
            ),
          ],
        ),
        RecordListView<StudentBalanceRow>(
          data: data,
          onRetry: () => ref.invalidate(balanceOverviewProvider),
          loadingMessage: 'Calculating balances…',
          searchHint: 'Search by student name or class',
          searchText: (s) => '${s.name} ${s.className ?? ''}',
          filters: const ['All', 'Owing', 'Paid up'],
          matchesFilter: (s, f) =>
              f == 'Owing' ? s.balance > 0 : s.balance <= 0,
          emptyIcon: Icons.account_box_outlined,
          emptyTitle: 'No students yet',
          emptyMessage: 'Students appear here once they are registered.',
          header: (items) {
            final owing = items.where((s) => s.owes).toList();
            final outstanding = owing.fold<double>(0, (t, s) => t + s.balance);
            return AdaptiveGrid(
              columns: 3,
              phoneColumns: 1,
              children: [
                MetricCard(
                  icon: Icons.people_outline_rounded,
                  label: 'Students',
                  value: '${items.length}',
                  noteTone: StatusTone.neutral,
                ),
                MetricCard(
                  icon: Icons.hourglass_empty_rounded,
                  label: 'With a balance',
                  value: '${owing.length}',
                  noteTone: StatusTone.warning,
                ),
                MetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total outstanding',
                  value: formatMwk(outstanding),
                  noteTone: StatusTone.neutral,
                ),
              ],
            );
          },
          columns: const [
            UiColumn('Student', flex: 16),
            UiColumn('Class', flex: 9, hideOnPhone: true),
            UiColumn('Fees due', flex: 10, hideOnPhone: true),
            UiColumn('Paid', flex: 10, hideOnPhone: true),
            UiColumn('Balance', flex: 10),
            UiColumn('Status', width: 112),
          ],
          rowOf: (s) => UiTableRow([
            PersonCell(
              s.name,
              subtitle: s.enrollmentStatus.replaceAll('_', ' '),
            ),
            UiCellText(s.className ?? '—'),
            UiCellText(formatMwk(s.feesDue)),
            UiCellText(formatMwk(s.paid)),
            UiCellText(formatMwk(s.balance), bold: true),
            Align(
              alignment: Alignment.centerLeft,
              child: s.balance > 0
                  ? const StatusPill('Balance due', tone: StatusTone.warning)
                  : s.balance < 0
                  ? const StatusPill('In credit', tone: StatusTone.info)
                  : const StatusPill('Paid in full', tone: StatusTone.success),
            ),
          ], onTap: () => openStudentAccount(context, s.studentId, s.name)),
        ),
      ],
    );
  }
}
