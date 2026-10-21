import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/export_service.dart';
import '../../../core/widgets/app_widgets.dart' show ErrorState, LoadingState;
import '../../../theme/app_tokens.dart';
import '../../../widgets/ui_kit.dart';
import '../../assessments/presentation/pages/guardian_academic_progress_page.dart';
import '../../assessments/presentation/pages/guardian_report_card_page.dart';
import '../../assessments/presentation/widgets/guardian_report_gate.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../calendar/domain/models/calendar_event.dart';
import '../../communications/data/communications_repository.dart';
import '../../communications/domain/models/notification_model.dart';
import '../../finance/presentation/pages/guardian_payment_history_page.dart';

/// A linked child as returned by the existing `studentguardian` query.
class GuardianChild {
  final String id;
  final String name;
  final String status;

  const GuardianChild(this.id, this.name, this.status);

  static List<GuardianChild> fromRows(List<Map<String, dynamic>> rows) => [
    for (final row in rows)
      if (row['student'] is Map)
        GuardianChild(
          (row['student'] as Map)['studentid'] as String,
          '${(row['student'] as Map)['firstname']} ${(row['student'] as Map)['lastname']}',
          '${(row['student'] as Map)['enrollmentstatus']}',
        ),
  ];
}

/// Current class of a child, used to pick the right calendar events. Null when
/// the placement cannot be read.
final _childClassProvider = FutureProvider.autoDispose
    .family<({String id, String name})?, String>((ref, studentId) async {
      try {
        final rows = await supabase
            .from('studentclasshistory')
            .select('classid, class(classroomname)')
            .eq('studentid', studentId)
            .isFilter('enddate', null)
            .limit(1);
        if (rows.isEmpty) return null;
        final r = rows.first;
        return (
          id: r['classid'] as String,
          name: (r['class'] as Map?)?['classroomname'] as String? ?? 'Class',
        );
      } catch (_) {
        return null;
      }
    });

final _childEventsProvider = FutureProvider.autoDispose
    .family<List<CalendarEvent>, String?>((ref, classId) {
      return CommunicationsRepository().upcomingEvents(classId: classId);
    });

final _guardianNoticesProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
      final uid = ref.watch(authProvider).user!.userId;
      final repo = CommunicationsRepository();
      final guardianId = await repo.guardianIdForUser(uid);
      return repo.notificationsForGuardian(guardianId);
    });

final _academicYearsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final rows = await supabase
          .from('academicyear')
          .select('academicyearid, academicyear, term')
          .order('academicyear', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    });

const _tabKeys = ['overview', 'results', 'fees', 'calendar'];
const _tabLabels = [
  'Overview',
  'Results',
  'Fees & payments',
  'Calendar & notices',
];

/// Guardian child workspace: pick a linked child, then work through Overview,
/// Results (behind the balance gate), Fees & payments and Calendar & notices.
///
/// Everything is read-only and comes from the existing queries; the server
/// still enforces the guardian link and the balance gate.
class GuardianChildPage extends ConsumerStatefulWidget {
  final String? initialStudentId;
  final String? initialTab;

  const GuardianChildPage({super.key, this.initialStudentId, this.initialTab});

  @override
  ConsumerState<GuardianChildPage> createState() => _GuardianChildPageState();
}

class _GuardianChildPageState extends ConsumerState<GuardianChildPage> {
  String? _studentId;
  late int _tab = () {
    final i = _tabKeys.indexOf(widget.initialTab ?? '');
    return i < 0 ? 0 : i;
  }();
  bool _showProgress = false;
  String? _yearId;

  @override
  void initState() {
    super.initState();
    _studentId = widget.initialStudentId;
  }

  void _setTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(guardianChildrenProvider);
    return PageFrame(
      kicker: 'Guardian',
      title: 'My Children',
      subtitle:
          'Switch between your children, then see results, fees and school updates in one place.',
      body: childrenAsync.when(
        loading: () => const LoadingState(message: 'Loading your children…'),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(guardianChildrenProvider),
        ),
        data: (rows) {
          final children = GuardianChild.fromRows(rows);
          if (children.isEmpty) {
            return const UiCard(
              child: UiEmptyState(
                icon: Icons.family_restroom_outlined,
                title: 'No children linked yet',
                message:
                    'No children linked to your account yet. Contact the school administrator.',
              ),
            );
          }
          final selected = children.firstWhere(
            (c) => c.id == _studentId,
            orElse: () => children.first,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (children.length > 1) ...[
                _switcher(children, selected),
                const SizedBox(height: 12),
              ],
              _hero(selected),
              TabsBar(tabs: _tabLabels, index: _tab, onChanged: _setTab),
              Expanded(child: _tabBody(selected)),
            ],
          );
        },
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _switcher(List<GuardianChild> children, GuardianChild selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in children)
          Material(
            color: c.id == selected.id
                ? AppColors.primarySurface
                : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: c.id == selected.id ? AppColors.primary : AppColors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() {
                _studentId = c.id;
                _showProgress = false;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MiniAvatar(c.name),
                    const SizedBox(width: 10),
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _hero(GuardianChild child) {
    final access = ref.watch(guardianReportAccessProvider(child.id));
    final klass = ref.watch(_childClassProvider(child.id)).value;
    return ProfileHero(
      name: child.name,
      subtitle: [
        ?klass?.name,
        child.status.replaceAll('_', ' '),
      ].join(' · '),
      pill: access.when(
        data: (a) => a.outstandingBalance > 0
            ? StatusPill(
                '${formatMwk(a.outstandingBalance)} outstanding',
                tone: StatusTone.warning,
              )
            : const StatusPill('Fees paid', tone: StatusTone.success),
        loading: () => const StatusPill('Checking fees…', tone: StatusTone.neutral),
        error: (_, _) =>
            const StatusPill('Fee status unavailable', tone: StatusTone.neutral),
      ),
    );
  }

  Widget _tabBody(GuardianChild child) {
    switch (_tab) {
      case 1:
        return _results(child);
      case 2:
        return _scroll(_fees(child));
      case 3:
        return _scroll(_calendar(child));
      default:
        return _scroll(_overview(child));
    }
  }

  Widget _scroll(Widget content) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 24),
    child: content,
  );

  // ── Overview ──────────────────────────────────────────────────────────────

  Widget _overview(GuardianChild child) {
    final access = ref.watch(guardianReportAccessProvider(child.id));
    final payments = ref.watch(guardianStudentPaymentsProvider(child.id));
    final klass = ref.watch(_childClassProvider(child.id)).value;
    final events = ref.watch(_childEventsProvider(klass?.id));
    final balance = access.value?.outstandingBalance;
    final allowed = access.value?.allowed;
    final latest = payments.value?.isNotEmpty == true ? payments.value!.first : null;
    final nextEvent = events.value?.isNotEmpty == true ? events.value!.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveGrid(
          columns: 3,
          phoneColumns: 1,
          children: [
            MetricCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Fee balance',
              value: balance == null ? null : formatMwk(balance, decimals: 0),
              note: allowed == null
                  ? 'Checking…'
                  : allowed
                  ? 'Nothing owed'
                  : 'Report card locked',
              noteTone: allowed == true ? StatusTone.success : StatusTone.warning,
            ),
            MetricCard(
              icon: Icons.assessment_outlined,
              label: 'Report card',
              value: allowed == null
                  ? null
                  : allowed
                  ? 'Available'
                  : 'Locked',
              note: allowed == true
                  ? 'Published results can be viewed'
                  : 'Opens when the balance is cleared',
              noteTone: allowed == true ? StatusTone.success : StatusTone.warning,
            ),
            MetricCard(
              icon: Icons.event_outlined,
              label: 'Next event',
              value: nextEvent == null ? '—' : formatUiDate(nextEvent.startTime),
              note: nextEvent?.eventName ?? 'No upcoming events',
              noteTone: StatusTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          columns: 2,
          phoneColumns: 1,
          children: [
            Panel(
              title: 'Report card',
              trailing: allowed == null
                  ? null
                  : allowed
                  ? const StatusPill('Available', tone: StatusTone.success)
                  : const StatusPill('Locked', tone: StatusTone.warning),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allowed == true
                        ? 'Published results are ready to view.'
                        : 'Results stay private until the outstanding balance is paid.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  UiButton(
                    allowed == false ? 'See why it is locked' : 'Open results',
                    onPressed: () => _setTab(1),
                  ),
                ],
              ),
            ),
            Panel(
              title: 'Latest payment',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latest == null
                        ? 'No payments recorded yet.'
                        : '${formatUiDate(DateTime.tryParse('${latest['paymentdate']}'))} · ${formatMwk((latest['amount'] as num).toDouble())} · ${latest['receiptnumber'] ?? 'no receipt number'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  UiButton.secondary('Fees & payments', onPressed: () => _setTab(2)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _results(GuardianChild child) {
    final years = ref.watch(_academicYearsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChipBox(
              'Report card',
              selected: !_showProgress,
              onTap: () => setState(() => _showProgress = false),
            ),
            FilterChipBox(
              'Term progress',
              selected: _showProgress,
              onTap: () => setState(() => _showProgress = true),
            ),
            if (_showProgress)
              years.when(
                data: (list) => SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _yearId,
                    isExpanded: true,
                    hint: const Text('Academic year'),
                    items: [
                      for (final y in list)
                        DropdownMenuItem(
                          value: y['academicyearid'] as String,
                          child: Text('${y['academicyear']} — ${y['term']}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _yearId = v),
                  ),
                ),
                loading: () => const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Text(friendlyError(e)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GuardianReportGate(
            studentId: child.id,
            lockedActions: [
              UiButton.secondary(
                'View payment history',
                icon: Icons.receipt_long_outlined,
                onPressed: () => _setTab(2),
              ),
              UiButton(
                'View statement',
                icon: Icons.description_outlined,
                onPressed: () => _setTab(2),
              ),
            ],
            child: _showProgress
                ? _progress(child, years.value ?? const [])
                : GuardianReportCardView(studentId: child.id, studentName: child.name),
          ),
        ),
      ],
    );
  }

  Widget _progress(GuardianChild child, List<Map<String, dynamic>> years) {
    final year = years.where((y) => y['academicyearid'] == _yearId).firstOrNull;
    if (year == null) {
      return const Center(
        child: Text(
          'Select an academic year',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return GuardianProgressView(
      studentId: child.id,
      studentName: child.name,
      yearId: _yearId!,
      yearLabel: '${year['academicyear']} — ${year['term']}',
    );
  }

  // ── Fees & payments ───────────────────────────────────────────────────────

  Future<void> _downloadStatement(GuardianChild child) async {
    try {
      final payments = await ref.read(
        guardianStudentPaymentsProvider(child.id).future,
      );
      final access = await ref.read(
        guardianReportAccessProvider(child.id).future,
      );
      await ExportService.exportToPdf(
        title: 'Statement of Account',
        subtitle: child.name,
        headers: const ['Date', 'Fee', 'Receipt', 'Method', 'Amount'],
        rows: [
          for (final p in payments)
            [
              formatUiDate(DateTime.tryParse('${p['paymentdate']}')),
              (p['feestructure'] as Map?)?['feetype'] as String? ?? 'Fee',
              '${p['receiptnumber'] ?? '—'}',
              '${p['method']}'.replaceAll('_', ' '),
              formatMwk((p['amount'] as num).toDouble()),
            ],
        ],
        footer:
            'Outstanding balance: ${formatMwk(access.outstandingBalance)}. Generated on ${DateTime.now().toIso8601String().substring(0, 10)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create the statement: ${friendlyError(e)}')),
        );
      }
    }
  }

  Widget _fees(GuardianChild child) {
    final access = ref.watch(guardianReportAccessProvider(child.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        access.when(
          loading: () => const LoadingState(message: 'Checking balance…'),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(guardianReportAccessProvider(child.id)),
          ),
          data: (a) => Panel(
            title: 'Statement of account',
            trailing: a.outstandingBalance > 0
                ? StatusPill('${formatMwk(a.outstandingBalance, decimals: 0)} outstanding', tone: StatusTone.warning)
                : const StatusPill('Nothing owed', tone: StatusTone.success),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.outstandingBalance > 0
                      ? 'The report card is withheld until this balance is cleared. Pay at the school; the Accountant records the payment and a receipt appears below.'
                      : 'No balance is owed. Receipts for every payment are listed below.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                UiButton.secondary(
                  'Download statement',
                  icon: Icons.download_outlined,
                  onPressed: () => _downloadStatement(child),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GuardianPaymentList(studentId: child.id, studentName: child.name),
      ],
    );
  }

  // ── Calendar & notices ────────────────────────────────────────────────────

  Widget _calendar(GuardianChild child) {
    final klass = ref.watch(_childClassProvider(child.id)).value;
    final events = ref.watch(_childEventsProvider(klass?.id));
    final notices = ref.watch(_guardianNoticesProvider);
    return AdaptiveGrid(
      columns: 2,
      phoneColumns: 1,
      children: [
        Panel(
          title: 'Upcoming events',
          trailing: PanelNote(
            klass?.name ?? 'School calendar',
            onTap: () => context.go('/calendar'),
          ),
          child: events.when(
            loading: () => const LoadingState(message: 'Loading events…'),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(_childEventsProvider(klass?.id)),
            ),
            data: (list) => list.isEmpty
                ? const UiEmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'No upcoming events',
                  )
                : Column(
                    children: [
                      for (final e in list.take(8))
                        DetailLine(
                          e.eventName,
                          '${formatUiDate(e.startTime)} · ${e.className ?? 'Whole school'}',
                        ),
                    ],
                  ),
          ),
        ),
        Panel(
          title: 'Notices',
          trailing: PanelNote(
            'Open all',
            onTap: () => context.go('/notifications'),
          ),
          child: notices.when(
            loading: () => const LoadingState(message: 'Loading notices…'),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(_guardianNoticesProvider),
            ),
            data: (list) => list.isEmpty
                ? const UiEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notices yet',
                  )
                : Column(
                    children: [
                      for (final n in list.take(8))
                        DetailLine(
                          n.subject,
                          '${n.isRead ? '' : 'New · '}${formatUiDate(n.createdAt.toLocal())}',
                          valueColor: n.isRead
                              ? null
                              : AppColors.primaryDark,
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
