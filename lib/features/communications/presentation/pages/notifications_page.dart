import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/permission_helper.dart';
import '../../../../core/auth/school_role_access.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/communications_repository.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final permHelper = await ref.watch(permissionHelperProvider.future);
  final isGuardian =
      permHelper != null && schoolRole(permHelper.roleName) == 'GUARDIAN';
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

/// Screens 51-52 - Notifications.
/// Guardians: see their own notifications, mark as read.
/// Staff / Admin: see all notifications, compose new ones.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  static const _pageSize = 25;
  String _filter = 'ALL'; // ALL | UNREAD | READ
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final permHelperAsync = ref.watch(permissionHelperProvider);
    final canCompose = permHelperAsync.maybeWhen(
      data: (perm) => perm != null && canSendNotifications(perm.roleName),
      orElse: () => false,
    );
    final isGuardian = permHelperAsync.maybeWhen(
      data: (perm) => perm != null && schoolRole(perm.roleName) == 'GUARDIAN',
      orElse: () => false,
    );
    final async = ref.watch(_notificationsProvider);

    return UiPage(
      children: [
        PageHead(
          kicker: 'Communication',
          title: 'Notifications',
          subtitle: 'Role-appropriate in-app notices with read status.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_notificationsProvider),
            ),
            if (canCompose)
              UiButton(
                'Send Notification',
                icon: Icons.send_outlined,
                onPressed: () => _showComposeDialog(context, ref),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in const [
                ('ALL', 'All'),
                ('UNREAD', 'Unread'),
                ('READ', 'Read'),
              ])
                FilterChipBox(
                  label,
                  selected: _filter == value,
                  onTap: () => setState(() {
                    _filter = value;
                    _page = 0;
                  }),
                ),
            ],
          ),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading notifications…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_notificationsProvider),
          ),
          data: (all) {
            final notifications = all.where((n) {
              final unread = n['readstatus'] == 'UNREAD';
              return switch (_filter) {
                'UNREAD' => unread,
                'READ' => !unread,
                _ => true,
              };
            }).toList();
            if (notifications.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications',
                  message: 'Nothing to show for this filter yet.',
                ),
              );
            }
            final pageCount = (notifications.length / _pageSize).ceil();
            final page = _page.clamp(0, pageCount - 1);
            final visible = PagerBar.slice(notifications, page, _pageSize);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTableCard(
                  columns: [
                    const UiColumn('Notice', flex: 20),
                    const UiColumn(
                      'Recipient / sender',
                      flex: 12,
                      hideOnPhone: true,
                    ),
                    const UiColumn('Sent', flex: 8, hideOnPhone: true),
                    const UiColumn('Status', flex: 8),
                    UiColumn(isGuardian ? 'Action' : '', width: 100),
                  ],
                  rows: [for (final n in visible) _row(context, n, isGuardian)],
                ),
                PagerBar(
                  total: notifications.length,
                  page: page,
                  pageSize: _pageSize,
                  onPage: (p) => setState(() => _page = p),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  UiTableRow _row(
    BuildContext context,
    Map<String, dynamic> n,
    bool isGuardian,
  ) {
    final isUnread = n['readstatus'] == 'UNREAD';
    final guardian = n['guardian'] as Map<String, dynamic>?;
    final sender = n['staff'] as Map<String, dynamic>?;
    return UiTableRow([
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            n['subject'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          Text(
            n['message'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64758B),
            ),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (guardian != null)
            UiCellText('To ${guardian['firstname']} ${guardian['lastname']}'),
          if (sender != null)
            Text(
              'From ${sender['firstname']} ${sender['lastname']}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64758B),
              ),
            ),
        ],
      ),
      UiCellText(
        formatUiDate(DateTime.tryParse('${n['createdat']}')?.toLocal()),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: isUnread
            ? const StatusPill('Unread', tone: StatusTone.info)
            : const StatusPill('Read', tone: StatusTone.neutral),
      ),
      isGuardian && isUnread
          ? TextButton(
              child: const Text('Mark read'),
              onPressed: () async {
                await CommunicationsRepository().markRead(
                  n['notificationid'] as String,
                );
                ref.invalidate(_notificationsProvider);
              },
            )
          : const SizedBox.shrink(),
    ], onTap: () => _showDetail(context, n));
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
                    decoration: const InputDecoration(labelText: 'Subject *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message *',
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
