import '../../../core/database/supabase_client.dart';

/// One attempt to email a notification (`email_delivery_log`).
///
/// The rendered message body is deliberately NOT loaded: account emails can
/// contain temporary credentials, and the log screen only needs delivery facts.
class EmailLogRow {
  final String id;
  final String recipientAddress;
  final String subject;
  final String messageType;
  final String status;
  final int retryCount;
  final String? failureReason;
  final DateTime? queuedAt;
  final DateTime? sentAt;

  const EmailLogRow({
    required this.id,
    required this.recipientAddress,
    required this.subject,
    required this.messageType,
    required this.status,
    required this.retryCount,
    required this.failureReason,
    required this.queuedAt,
    required this.sentAt,
  });

  factory EmailLogRow.fromJson(Map<String, dynamic> j) => EmailLogRow(
    id: j['email_log_id'] as String,
    recipientAddress: j['recipient_address'] as String? ?? '—',
    subject: j['subject'] as String? ?? '—',
    messageType: j['message_type'] as String? ?? '—',
    status: j['status'] as String? ?? '',
    retryCount: (j['retry_count'] as num?)?.toInt() ?? 0,
    failureReason: j['failure_reason'] as String?,
    queuedAt: DateTime.tryParse('${j['queued_at']}')?.toLocal(),
    sentAt: j['sent_at'] == null
        ? null
        : DateTime.tryParse('${j['sent_at']}')?.toLocal(),
  );
}

class EmailLogRepository {
  Future<List<EmailLogRow>> list() async {
    final rows = await supabase
        .from('email_delivery_log')
        .select(
          'email_log_id, recipient_address, subject, message_type, status, '
          'retry_count, failure_reason, queued_at, sent_at',
        )
        .order('queued_at', ascending: false)
        .limit(1000);
    return [for (final r in rows) EmailLogRow.fromJson(r)];
  }
}
