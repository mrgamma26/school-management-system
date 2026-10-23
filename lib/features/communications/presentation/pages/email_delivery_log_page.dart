import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_record_list.dart';
import '../../data/email_log_repository.dart';

final _emailLogProvider = FutureProvider.autoDispose<List<EmailLogRow>>(
  (ref) => EmailLogRepository().list(),
);

StatusTone _toneFor(String status) => switch (status) {
  'SENT' => StatusTone.success,
  'FAILED' => StatusTone.danger,
  'QUEUED' => StatusTone.warning,
  _ => StatusTone.neutral,
};

String _labelFor(String status) =>
    status.isEmpty ? '—' : status[0] + status.substring(1).toLowerCase();

String _dateTime(DateTime? value) {
  if (value == null) return '—';
  return '${formatUiDate(value)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

/// Screen 53 - Email delivery log (read-only, Super User).
class EmailDeliveryLogPage extends ConsumerWidget {
  const EmailDeliveryLogPage({super.key});

  void _showDetail(BuildContext context, EmailLogRow r) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email delivery'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: DialogDetailList([
              ('Recipient', r.recipientAddress),
              ('Subject', r.subject),
              ('Type', r.messageType),
              ('Status', _labelFor(r.status)),
              ('Queued', _dateTime(r.queuedAt)),
              ('Sent', _dateTime(r.sentAt)),
              ('Retries', '${r.retryCount}'),
              if (r.failureReason != null) ('Failure reason', r.failureReason!),
            ]),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_emailLogProvider);
    return UiPage(
      children: [
        PageHead(
          kicker: 'Administration',
          title: 'Email Delivery Log',
          subtitle: 'Every email the system tried to send, and what happened.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_emailLogProvider),
            ),
          ],
        ),
        RecordListView<EmailLogRow>(
          data: data,
          onRetry: () => ref.invalidate(_emailLogProvider),
          loadingMessage: 'Loading email log…',
          searchHint: 'Search recipient, subject or type',
          searchText: (r) =>
              '${r.recipientAddress} ${r.subject} ${r.messageType}',
          filters: const ['All', 'Queued', 'Sent', 'Failed'],
          matchesFilter: (r, f) => _labelFor(r.status) == f,
          emptyIcon: Icons.mark_email_unread_outlined,
          emptyTitle: 'No emails have been logged yet',
          header: (items) => AdaptiveGrid(
            columns: 3,
            phoneColumns: 1,
            children: [
              MetricCard(
                icon: Icons.schedule_send_outlined,
                label: 'Queued',
                value: '${items.where((r) => r.status == 'QUEUED').length}',
                noteTone: StatusTone.warning,
              ),
              MetricCard(
                icon: Icons.mark_email_read_outlined,
                label: 'Sent',
                value: '${items.where((r) => r.status == 'SENT').length}',
                noteTone: StatusTone.neutral,
              ),
              MetricCard(
                icon: Icons.error_outline_rounded,
                label: 'Failed',
                value: '${items.where((r) => r.status == 'FAILED').length}',
                noteTone: StatusTone.danger,
              ),
            ],
          ),
          columns: const [
            UiColumn('Recipient', flex: 14),
            UiColumn('Subject', flex: 16, hideOnPhone: true),
            UiColumn('Type', flex: 9, hideOnPhone: true),
            UiColumn('Queued', flex: 11, hideOnPhone: true),
            UiColumn('Status', width: 100),
          ],
          rowOf: (r) => UiTableRow([
            UiCellText(r.recipientAddress, bold: true),
            UiCellText(r.subject),
            UiCellText(r.messageType),
            UiCellText(_dateTime(r.queuedAt)),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(_labelFor(r.status), tone: _toneFor(r.status)),
            ),
          ], onTap: () => _showDetail(context, r)),
        ),
      ],
    );
  }
}
