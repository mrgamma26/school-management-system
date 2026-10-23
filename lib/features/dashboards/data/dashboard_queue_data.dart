// lib/features/dashboards/data/dashboard_queue_data.dart
// Real, RLS-scoped "what is waiting" items for the role dashboards. Every entry
// names a real record and carries the route that opens it. All queries are
// read-only and run as the signed-in user. When a role has nothing waiting the
// list is empty; when the data cannot be read the provider errors so the
// dashboard falls back to its static shortcut links. Nothing is estimated.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/supabase_client.dart';
import '../../../widgets/ui_kit.dart';
import '../../assessments/data/mark_workspace_repository.dart';
import '../../assessments/data/results_review_repository.dart';
import '../../assessments/data/review_workspace_repository.dart';
import '../../assessments/presentation/widgets/guardian_report_gate.dart'
    show GuardianReportAccess;
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../finance/data/student_account_repository.dart';

/// Most rows a dashboard queue shows.
const kDashboardQueueCap = 5;

/// One actionable row: names the record, says why it is waiting, opens it.
class DashboardQueueEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String pill;
  final StatusTone tone;
  final String route;

  const DashboardQueueEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.tone,
    required this.route,
  });
}

typedef _Source = Future<List<DashboardQueueEntry>> Function();

// ── Helpers ─────────────────────────────────────────────────────────────────

String _person(Object? row) {
  if (row is! Map) return '';
  final first = row['firstname']?.toString().trim() ?? '';
  final last = row['lastname']?.toString().trim() ?? '';
  return '$first $last'.trim();
}

String _clip(String text, [int max = 90]) {
  final t = text.trim();
  return t.length <= max ? t : '${t.substring(0, max - 1).trimRight()}…';
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

String _titleCase(String raw) => raw
    .replaceAll('_', ' ')
    .toLowerCase()
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Runs [source], returning null when it fails.
Future<List<DashboardQueueEntry>?> _attempt(_Source source) async {
  try {
    return await source();
  } catch (_) {
    return null;
  }
}

/// Runs the sources side by side and merges them in order. Each source keeps at
/// most its [caps] entry first; unused room is then handed to later sources.
/// Throws when every source failed, or when some failed and the rest are empty
/// (an empty list would wrongly claim nothing is waiting).
Future<List<DashboardQueueEntry>> _merge(
  List<_Source> sources,
  List<int> caps,
) async {
  final parts = await Future.wait([for (final s in sources) _attempt(s)]);
  final readable = parts.whereType<List<DashboardQueueEntry>>().toList();
  if (readable.isEmpty) {
    throw StateError('The queue could not be read.');
  }
  final failedSome = readable.length != parts.length;
  if (failedSome && readable.every((p) => p.isEmpty)) {
    throw StateError('The queue could only be partly read.');
  }
  return _mergeLists([
    for (final p in parts) p ?? const <DashboardQueueEntry>[],
  ], caps);
}

/// Reads up to three pages of 1000 rows.
Future<List<Map<String, dynamic>>> _pages(
  Future<List<Map<String, dynamic>>> Function(int from, int to) page,
) async {
  final rows = <Map<String, dynamic>>[];
  for (var i = 0; i < 3; i++) {
    final chunk = await page(i * 1000, (i + 1) * 1000 - 1);
    rows.addAll(chunk);
    if (chunk.length < 1000) break;
  }
  return rows;
}

// ── Head Teacher ────────────────────────────────────────────────────────────

/// Assessments with submitted, unpublished marks (same query as the review
/// workspace).
Future<List<DashboardQueueEntry>> _headTeacherReviews() async {
  final queue = await ReviewWorkspaceRepository().queue();
  return [
    for (final item in queue)
      DashboardQueueEntry(
        icon: Icons.assignment_turned_in_outlined,
        title: '${item.name} · ${item.subjectName}, ${item.className}',
        subtitle:
            '${item.awaitingGrades} submitted '
            '${item.awaitingGrades == 1 ? 'mark' : 'marks'} awaiting review'
            '${item.teacherName.isEmpty ? '' : ' from ${item.teacherName}'}',
        pill: 'Awaiting review',
        tone: StatusTone.warning,
        route: '/results/review?assessment=${item.assessmentId}',
      ),
  ];
}

/// Result correction requests still PENDING a decision.
Future<List<DashboardQueueEntry>> _headTeacherCorrections() async {
  final requests = await ResultsReviewRepository().listCorrectionRequests();
  return [
    for (final r in requests)
      if (r.isPending)
        DashboardQueueEntry(
          icon: Icons.edit_note_outlined,
          title: '${r.studentName} · ${r.assessmentName}',
          subtitle: '${r.subjectName}, ${r.className}: ${_clip(r.reason, 70)}',
          pill: 'Correction pending',
          tone: StatusTone.warning,
          route: '/results/corrections',
        ),
  ];
}

// ── Teacher ─────────────────────────────────────────────────────────────────

/// Assessments of the teacher's current classes where a rostered student has no
/// mark and no recorded absence.
Future<List<DashboardQueueEntry>> _teacherMissingMarks(String? userId) async {
  if (userId == null) throw StateError('No signed-in user.');
  final workspace = MarkWorkspaceRepository();
  final staffId = await workspace.staffIdForUser(userId);
  if (staffId == null) throw StateError('No staff profile for this account.');
  final today = DateTime.now();
  final current = (await workspace.assignments(
    staffId,
  )).where((a) => a.isCurrent(today)).take(8).toList();
  if (current.isEmpty) return const [];

  final rows = await supabase
      .from('assessment')
      .select(
        'assessmentid, assessmentname, classsubjectid, '
        'grade(studentid, score, gradestatus)',
      )
      .inFilter('classsubjectid', [for (final a in current) a.classSubjectId])
      .order('createdat', ascending: false)
      .limit(100);
  final rosters = await Future.wait([
    for (final a in current) workspace.roster(a.classSubjectId),
  ]);
  final byClassSubject = {
    for (var i = 0; i < current.length; i++) current[i].classSubjectId: i,
  };

  final found = <({DashboardQueueEntry entry, int missing})>[];
  for (final row in rows as List) {
    final r = Map<String, dynamic>.from(row as Map);
    final index = byClassSubject['${r['classsubjectid']}'];
    if (index == null) continue;
    final roster = rosters[index];
    if (roster.isEmpty) continue;
    final marked = <String>{};
    for (final g in (r['grade'] as List? ?? const [])) {
      final grade = Map<String, dynamic>.from(g as Map);
      final absent = '${grade['gradestatus']}'.toUpperCase() == 'ABSENT';
      if (grade['score'] != null || absent) marked.add('${grade['studentid']}');
    }
    final missing = roster.where((s) => !marked.contains(s.studentId)).length;
    if (missing == 0) continue;
    final a = current[index];
    found.add((
      missing: missing,
      entry: DashboardQueueEntry(
        icon: Icons.edit_note_outlined,
        title: '${r['assessmentname']} · ${a.subjectName}, ${a.className}',
        subtitle: '$missing of ${roster.length} marks still to enter',
        pill: 'Marks missing',
        tone: StatusTone.warning,
        route: '/assessments/${r['assessmentid']}/grades',
      ),
    ));
  }
  found.sort((a, b) => b.missing.compareTo(a.missing));
  return [for (final f in found) f.entry];
}

// ── Accountant ──────────────────────────────────────────────────────────────

/// Deposit slips still PENDING verification, oldest first.
Future<List<DashboardQueueEntry>> _pendingDepositSlips() async {
  final rows = await supabase
      .from('deposit_slips')
      .select(
        'deposit_slip_id, bank_name, amount, created_at, '
        'student(firstname, lastname)',
      )
      .eq('status', 'PENDING')
      .order('created_at')
      .limit(kDashboardQueueCap);
  return [
    for (final row in rows as List)
      () {
        final r = Map<String, dynamic>.from(row as Map);
        final name = _person(r['student']);
        final amount = (r['amount'] as num?)?.toDouble();
        return DashboardQueueEntry(
          icon: Icons.receipt_long_outlined,
          title: name.isEmpty ? 'Deposit slip' : '$name · deposit slip',
          subtitle: [
            if (r['bank_name'] != null) '${r['bank_name']}',
            if (amount != null) formatMwk(amount, decimals: 0),
            formatUiDate(_date(r['created_at'])),
          ].join(' · '),
          pill: 'To verify',
          tone: StatusTone.warning,
          route: '/finance/deposit-slips',
        );
      }(),
  ];
}

/// Students owing the most, from the same ledger the Overdue Accounts page uses.
Future<List<DashboardQueueEntry>> _largestBalances() async {
  final rows = await StudentAccountRepository().loadBalanceOverview();
  final owing = rows.where((r) => r.owes).toList()
    ..sort((a, b) => b.balance.compareTo(a.balance));
  return [
    for (final r in owing.take(kDashboardQueueCap))
      DashboardQueueEntry(
        icon: Icons.account_balance_wallet_outlined,
        title: r.name,
        subtitle:
            'Owes ${formatMwk(r.balance, decimals: 0)}'
            '${r.className == null ? '' : ' · ${r.className}'}',
        pill: 'Outstanding',
        tone: StatusTone.danger,
        route:
            '/finance/students/${r.studentId}/account'
            '?name=${Uri.encodeQueryComponent(r.name)}',
      ),
  ];
}

// ── Administrator ───────────────────────────────────────────────────────────

/// Enrolled students with no open class placement, and students with no
/// guardian link.
Future<
  ({List<DashboardQueueEntry> noGuardian, List<DashboardQueueEntry> noClass})
>
_administratorGaps() async {
  final rows = await _pages(
    (from, to) => supabase
        .from('student')
        .select(
          'studentid, firstname, lastname, enrollmentstatus, '
          'studentguardian(guardianid), studentclasshistory(enddate)',
        )
        .order('studentid')
        .range(from, to),
  );
  final noGuardian = <DashboardQueueEntry>[];
  final noClass = <DashboardQueueEntry>[];
  for (final r in rows) {
    final enrolled = '${r['enrollmentstatus']}'.toLowerCase() == 'enrolled';
    if (!enrolled) continue;
    final name = _person(r);
    final id = '${r['studentid']}';
    final guardians = r['studentguardian'] as List? ?? const [];
    final placements = r['studentclasshistory'] as List? ?? const [];
    final hasOpenPlacement = placements.any(
      (p) => p is Map && p['enddate'] == null,
    );
    if (guardians.isEmpty) {
      noGuardian.add(
        DashboardQueueEntry(
          icon: Icons.family_restroom_outlined,
          title: name.isEmpty ? 'Student without a name' : name,
          subtitle: 'No guardian linked yet',
          pill: 'No guardian',
          tone: StatusTone.warning,
          route: '/students/$id/link-guardian',
        ),
      );
    }
    if (!hasOpenPlacement) {
      noClass.add(
        DashboardQueueEntry(
          icon: Icons.class_outlined,
          title: name.isEmpty ? 'Student without a name' : name,
          subtitle: 'Enrolled but not placed in a class',
          pill: 'No class',
          tone: StatusTone.warning,
          route: '/students/$id/class-history',
        ),
      );
    }
  }
  return (noGuardian: noGuardian, noClass: noClass);
}

// ── Super User ──────────────────────────────────────────────────────────────

/// Failed and queued emails (status counts only; no addresses or bodies).
Future<List<DashboardQueueEntry>> _emailAttention() async {
  Future<int> countStatus(String status) async {
    final result = await supabase
        .from('email_delivery_log')
        .select('email_log_id')
        .eq('status', status)
        .limit(0)
        .count(CountOption.exact);
    return result.count;
  }

  final counts = await Future.wait([
    countStatus('FAILED'),
    countStatus('QUEUED'),
  ]);
  final failed = counts[0], queued = counts[1];
  return [
    if (failed > 0)
      DashboardQueueEntry(
        icon: Icons.mark_email_unread_outlined,
        title: '$failed ${failed == 1 ? 'email' : 'emails'} failed to send',
        subtitle: 'Open the email log to see the reason for each',
        pill: 'Failed',
        tone: StatusTone.danger,
        route: '/admin/email-log',
      ),
    if (queued > 0)
      DashboardQueueEntry(
        icon: Icons.schedule_send_outlined,
        title: '$queued ${queued == 1 ? 'email is' : 'emails are'} queued',
        subtitle: 'Waiting to be sent',
        pill: 'Queued',
        tone: StatusTone.info,
        route: '/admin/email-log',
      ),
  ];
}

/// The latest audit-log entries.
Future<List<DashboardQueueEntry>> _recentAudit() async {
  final rows = await supabase
      .from('auditlog')
      .select('auditid, action, tablename, createdat, userid(username)')
      .order('createdat', ascending: false)
      .limit(3);
  return [
    for (final row in rows as List)
      () {
        final r = Map<String, dynamic>.from(row as Map);
        final user = r['userid'];
        final username = user is Map ? user['username']?.toString() : null;
        return DashboardQueueEntry(
          icon: Icons.history_rounded,
          title: _titleCase('${r['action']}'),
          subtitle: [
            if (r['tablename'] != null) 'on ${r['tablename']}',
            if (username != null && username.isNotEmpty) 'by $username',
            formatUiDate(_date(r['createdat'])),
          ].join(' · '),
          pill: 'Recent',
          tone: StatusTone.neutral,
          route: '/admin/audit-log',
        );
      }(),
  ];
}

// ── Guardian ────────────────────────────────────────────────────────────────

/// Each linked child with whether the backend currently allows their results.
Future<List<DashboardQueueEntry>> _guardianChildren(String? userId) async {
  if (userId == null) throw StateError('No signed-in user.');
  final guardian = await supabase
      .from('guardian')
      .select('guardianid')
      .eq('userid', userId)
      .maybeSingle();
  if (guardian == null) throw StateError('No guardian profile.');
  final links = await supabase
      .from('studentguardian')
      .select('student(studentid, firstname, lastname)')
      .eq('guardianid', guardian['guardianid'] as String);
  final children = <({String id, String name})>[
    for (final l in links as List)
      if (l is Map && l['student'] is Map)
        (
          id: '${(l['student'] as Map)['studentid']}',
          name: _person(l['student']),
        ),
  ];
  final entries = await Future.wait([
    for (final child in children.take(3))
      () async {
        try {
          final result = await supabase.rpc(
            'get_guardian_report_access',
            params: {'p_student_id': child.id},
          );
          final access = GuardianReportAccess.fromJson(
            Map<String, dynamic>.from(result as Map),
          );
          return access.allowed
              ? DashboardQueueEntry(
                  icon: Icons.assessment_outlined,
                  title: child.name,
                  subtitle: 'Results are available to open',
                  pill: 'Available',
                  tone: StatusTone.success,
                  route: '/guardian/child?student=${child.id}&tab=results',
                )
              : DashboardQueueEntry(
                  icon: Icons.lock_outline_rounded,
                  title: child.name,
                  subtitle:
                      'Results blocked until the balance of '
                      '${formatMwk(access.outstandingBalance, decimals: 0)} '
                      'is paid',
                  pill: 'Blocked',
                  tone: StatusTone.danger,
                  route: '/guardian/child?student=${child.id}&tab=fees',
                );
        } catch (_) {
          return null;
        }
      }(),
  ]);
  final readable = entries.whereType<DashboardQueueEntry>().toList();
  if (children.isNotEmpty && readable.isEmpty) {
    throw StateError('Report access could not be read.');
  }
  return readable;
}

/// The guardian's unread notices, newest first.
Future<List<DashboardQueueEntry>> _unreadNotices() async {
  final rows = await supabase
      .from('notification')
      .select('notificationid, subject, createdat')
      .eq('readstatus', 'UNREAD')
      .order('createdat', ascending: false)
      .limit(3);
  return [
    for (final row in rows as List)
      () {
        final r = Map<String, dynamic>.from(row as Map);
        final subject = '${r['subject'] ?? ''}'.trim();
        return DashboardQueueEntry(
          icon: Icons.notifications_none_rounded,
          title: subject.isEmpty ? 'School notice' : _clip(subject, 80),
          subtitle: 'Unread notice · ${formatUiDate(_date(r['createdat']))}',
          pill: 'Unread',
          tone: StatusTone.info,
          route: '/notifications',
        );
      }(),
  ];
}

// ── Provider ────────────────────────────────────────────────────────────────

/// Actionable queue for [role] (a canonical role name such as `HEAD_TEACHER`).
/// Errors when the data cannot be read; callers then show static links.
final dashboardQueueProvider = FutureProvider.autoDispose
    .family<List<DashboardQueueEntry>, String>((ref, role) {
      final userId = ref.watch(authProvider).user?.userId;
      return switch (role) {
        'HEAD_TEACHER' => _merge(
          [_headTeacherReviews, _headTeacherCorrections],
          [3, 2],
        ),
        'TEACHER' => _teacherMissingMarks(userId),
        'ACCOUNTANT' => _merge(
          [_pendingDepositSlips, _largestBalances],
          [3, 2],
        ),
        'ADMINISTRATOR' => _administratorGaps().then(
          (gaps) => _mergeLists([gaps.noGuardian, gaps.noClass], [3, 2]),
        ),
        'SUPER_USER' => _merge([_emailAttention, _recentAudit], [2, 3]),
        'GUARDIAN' => _merge(
          [() => _guardianChildren(userId), _unreadNotices],
          [3, 2],
        ),
        _ => Future.error(ArgumentError.value(role, 'role')),
      };
    }, retry: (retryCount, error) => null);

/// [_merge] for lists that are already loaded.
List<DashboardQueueEntry> _mergeLists(
  List<List<DashboardQueueEntry>> parts,
  List<int> caps,
) {
  final counts = <int>[];
  var used = 0;
  for (var i = 0; i < parts.length; i++) {
    final take = parts[i].length < caps[i] ? parts[i].length : caps[i];
    counts.add(take);
    used += take;
  }
  for (var i = 0; i < parts.length && used < kDashboardQueueCap; i++) {
    final room = kDashboardQueueCap - used;
    final extra = parts[i].length - counts[i];
    final add = extra < room ? extra : room;
    counts[i] += add;
    used += add;
  }
  return [for (var i = 0; i < parts.length; i++) ...parts[i].take(counts[i])];
}
