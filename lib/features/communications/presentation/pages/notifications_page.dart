import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/communications_repository.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/auth/permission_helper.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final permHelper = await ref.watch(permissionHelperProvider.future);
  final isGuardian = permHelper?.has('notifications:view_own') ?? false;
  final uid = ref.watch(authProvider).user?.userId ?? '';

  List<dynamic> rows;
  if (isGuardian) {
    final g = await supabase
        .from('guardian')
        .select('guardianid')
        .eq('userid', uid)
        .maybeSingle();
    if (g == null) return [];
    rows = await supabase
        .from('notification')
        .select(
          '*, guardian(firstname, lastname), '
          'staff!sentby(firstname, lastname)',
        )
        .eq('guardianid', g['guardianid'] as String)
        .order('createdat', ascending: false);
  } else {
    rows = await supabase
        .from('notification')
        .select(
          '*, guardian(firstname, lastname), '
          'staff!sentby(firstname, lastname)',
        )
        .order('createdat', ascending: false);
  }
  return List<Map<String, dynamic>>.from(rows);
});

final _guardiansForSelectProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('guardian')
      .select('guardianid, firstname, lastname')
      .order('lastname');
  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// Notifications page.
/// Guardians: see their own notifications, mark as read.
/// Staff / Admin: see all notifications, compose new ones.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permHelperAsync = ref.watch(permissionHelperProvider);
    final canCompose = permHelperAsync.maybeWhen(
      data: (perm) => perm?.isAtLeast(UserRole.staff) ?? false,
      orElse: () => false,
    );
    final async = ref.watch(_notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      floatingActionButton: canCompose
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.send),
              label: const Text('Send Notification'),
              onPressed: () => _showComposeDialog(context, ref),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading notifications: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = notifications[i];
              final isUnread = n['readstatus'] == 'UNREAD';
              final guardian = n['guardian'] as Map<String, dynamic>?;
              final sender = n['staff'] as Map<String, dynamic>?;
              final isGuardian = permHelperAsync.maybeWhen(
                data: (perm) => perm?.has('notifications:view_own') ?? false,
                orElse: () => false,
              );

              return Card(
                color: isUnread
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.06)
                    : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isUnread
                        ? Colors.blue
                        : Colors.grey.shade300,
                    child: Icon(
                      isUnread
                          ? Icons.notifications_active
                          : Icons.notifications,
                      color: isUnread ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    n['subject'] as String,
                    style: TextStyle(
                      fontWeight: isUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n['message'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (guardian != null)
                        Text(
                          'To: ${guardian['firstname']} ${guardian['lastname']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      if (sender != null)
                        Text(
                          'From: ${sender['firstname']} ${sender['lastname']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: isGuardian && isUnread
                      ? TextButton(
                          child: const Text('Mark Read'),
                          onPressed: () async {
                            await CommunicationsRepository().markRead(
                              n['notificationid'] as String,
                            );
                            ref.invalidate(_notificationsProvider);
                          },
                        )
                      : null,
                  onTap: () => _showDetail(context, n),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n['subject'] as String),
        content: SingleChildScrollView(child: Text(n['message'] as String)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showComposeDialog(BuildContext context, WidgetRef ref) async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String? guardianId;

    await showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final guardiansAsync = ref.watch(_guardiansForSelectProvider);
          return AlertDialog(
            title: const Text('Send Notification'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  guardiansAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (guardians) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'To (Guardian) *',
                        border: OutlineInputBorder(),
                      ),
                      items: guardians
                          .map(
                            (g) => DropdownMenuItem(
                              value: g['guardianid'] as String,
                              child: Text('${g['firstname']} ${g['lastname']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => guardianId = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (guardianId == null ||
                      subjectCtrl.text.trim().isEmpty ||
                      messageCtrl.text.trim().isEmpty) {
                    return;
                  }

                  final actor = ref.read(authProvider).user!;
                  final staffRow = await supabase
                      .from('staff')
                      .select('staffid')
                      .eq('userid', actor.userId)
                      .single();

                  await CommunicationsRepository().sendNotification(
                    guardianId: guardianId!,
                    staffId: staffRow['staffid'] as String,
                    subject: subjectCtrl.text.trim(),
                    message: messageCtrl.text.trim(),
                  );

                  await AuditService().log(
                    userId: actor.userId,
                    action: 'NOTIFICATION_SENT',
                    tableName: 'notification',
                    actorRole: actor.roleName,
                    newValue: {
                      'guardianId': guardianId,
                      'subject': subjectCtrl.text.trim(),
                    },
                  );

                  ref.invalidate(_notificationsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Send'),
              ),
            ],
          );
        },
      ),
    );
    subjectCtrl.dispose();
    messageCtrl.dispose();
  }
}
