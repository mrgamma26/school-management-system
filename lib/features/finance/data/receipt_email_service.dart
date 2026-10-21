import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/supabase_client.dart';
import '../../../core/services/audit_service.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../communications/data/communications_repository.dart';
import '../domain/models/payment_receipt.dart';
import '../domain/receipt_email.dart';

/// Outcome of one "email receipt" action.
class ReceiptEmailResult {
  /// Notifications that were created (and queued for email).
  final List<ReceiptRecipient> sent;

  /// Guardians whose notification could not be created, with the reason.
  final Map<ReceiptRecipient, String> failed;

  /// True when the audit row could not be written.
  final bool auditFailed;

  const ReceiptEmailResult({
    required this.sent,
    this.failed = const {},
    this.auditFailed = false,
  });
}

/// Sends the receipt email to [recipients]. Replaced in widget tests.
typedef ReceiptEmailSender =
    Future<ReceiptEmailResult> Function({
      required PaymentReceiptData receipt,
      required String schoolName,
      required List<ReceiptRecipient> recipients,
    });

/// Guardians linked to a student (all of them, with or without an email).
/// Reads `studentguardian` -> `guardian` through the signed-in user's RLS.
final receiptRecipientsProvider = FutureProvider.autoDispose
    .family<List<ReceiptRecipient>, String>((ref, studentId) async {
      final rows = await supabase
          .from('studentguardian')
          .select(
            'relationship, guardian(guardianid, firstname, lastname, email)',
          )
          .eq('studentid', studentId);
      final out = <ReceiptRecipient>[];
      for (final row in rows) {
        final g = row['guardian'];
        if (g is! Map) continue;
        final name = [g['firstname'], g['lastname']]
            .whereType<String>()
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .join(' ');
        out.add(
          ReceiptRecipient(
            guardianId: g['guardianid'] as String,
            name: name.isEmpty ? 'Guardian' : name,
            email: (g['email'] as String?)?.trim(),
            relationship: row['relationship'] as String?,
          ),
        );
      }
      return out;
    });

/// Real sender: one notification per guardian through
/// [CommunicationsRepository.sendNotification], then one audit row.
final receiptEmailSenderProvider = Provider<ReceiptEmailSender>((ref) {
  return ({
    required PaymentReceiptData receipt,
    required String schoolName,
    required List<ReceiptRecipient> recipients,
  }) async {
    final actor = ref.read(authProvider).user;
    if (actor == null) {
      throw StateError('You are signed out. Sign in again to email receipts.');
    }
    final repo = CommunicationsRepository();
    final staffId = await repo.staffIdForUser(actor.userId);
    final subject = receiptEmailSubject(receipt);
    final message = buildReceiptEmailMessage(
      schoolName: schoolName,
      receipt: receipt,
    );

    final sent = <ReceiptRecipient>[];
    final failed = <ReceiptRecipient, String>{};
    for (final r in recipients) {
      try {
        await repo.sendNotification(
          guardianId: r.guardianId,
          staffId: staffId,
          subject: subject,
          message: message,
        );
        sent.add(r);
      } catch (e) {
        failed[r] = e.toString();
      }
    }

    var auditFailed = false;
    if (sent.isEmpty) {
      return ReceiptEmailResult(sent: sent, failed: failed);
    }
    try {
      await AuditService().log(
        userId: actor.userId,
        action: 'RECEIPT_EMAILED',
        tableName: 'payment',
        recordId: receipt.paymentId,
        actorRole: actor.roleName,
        newValue: {
          'receiptNumber': receipt.receiptNumber,
          'guardianIds': [for (final r in sent) r.guardianId],
          'failedGuardianIds': [for (final r in failed.keys) r.guardianId],
        },
      );
    } catch (_) {
      auditFailed = true;
    }
    return ReceiptEmailResult(
      sent: sent,
      failed: failed,
      auditFailed: auditFailed,
    );
  };
});

/// One-line summary of [result] for a snack bar.
String receiptEmailOutcomeMessage(ReceiptEmailResult result) {
  final sent = result.sent.length;
  final failed = result.failed.length;
  final parts = <String>[];
  if (sent > 0) {
    parts.add(
      'Receipt queued for email to $sent guardian${sent == 1 ? '' : 's'}.',
    );
  }
  if (failed > 0) {
    parts.add(
      'Could not send to ${result.failed.keys.map((r) => r.name).join(', ')}.',
    );
  }
  if (sent > 0 && result.auditFailed) {
    parts.add('The audit log entry could not be saved.');
  }
  return parts.join(' ');
}
