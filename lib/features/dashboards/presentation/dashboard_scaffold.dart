import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/supabase_client.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/ui_kit.dart';
import '../data/dashboard_queue_data.dart';

/// Tables a dashboard metric may count. A whitelist keeps the family provider
/// from being used to probe arbitrary table names.
const _countableTables = <String>{
  'student',
  'staff',
  'guardian',
  'systemuser',
  'class',
  'payment',
  'deposit_slips',
  'feestructure',
  'assessment',
  'teacher_assignments',
  'teachercomment',
  'result_correction_requests',
  'progressionreview',
  'weedingreview',
  'notification',
  'calendarevent',
  'email_delivery_log',
};

/// Row count for [table] as the signed-in user sees it (RLS applies).
final dashboardCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  table,
) async {
  if (!_countableTables.contains(table)) {
    throw ArgumentError.value(table, 'table');
  }
  final result = await supabase
      .from(table)
      .select()
      .limit(0)
      .count(CountOption.exact);
  return result.count;
});

/// One KPI card. [watch] reads the count so each role can choose its provider.
class DashboardMetric {
  final IconData icon;
  final String label;
  final String? note;
  final String? route;
  final AsyncValue<int> Function(WidgetRef ref) watch;

  const DashboardMetric({
    required this.icon,
    required this.label,
    required this.watch,
    this.note,
    this.route,
  });

  /// Metric that counts the rows of a whitelisted table.
  factory DashboardMetric.table({
    required IconData icon,
    required String label,
    required String table,
    String? note,
    String? route,
  }) => DashboardMetric(
    icon: icon,
    label: label,
    note: note,
    route: route,
    watch: (ref) => ref.watch(dashboardCountProvider(table)),
  );
}

/// A destination shown as a queue row or shortcut. [push] keeps the back stack.
class DashboardLink {
  final String label;
  final String? detail;
  final IconData icon;
  final String route;
  final bool push;

  const DashboardLink(
    this.label,
    this.icon,
    this.route, {
    this.detail,
    this.push = false,
  });
}

/// A titled panel of shortcuts, e.g. "Academic structure".
class DashboardGroup {
  final String title;
  final List<DashboardLink> links;
  const DashboardGroup(this.title, this.links);
}

/// Shared layout for the six role dashboards (screens 2-7 of the redesign):
/// page head, quick start, role charts, KPI cards, attention queue and grouped
/// shortcuts. Header buttons live in the left menu (see role_menus.dart).
class RoleDashboard extends ConsumerWidget {
  final String kicker;
  final String title;
  final String subtitle;

  /// The role's three most common tasks, shown right under the page head.
  /// Each link's [DashboardLink.detail] is the one-line hint.
  final List<DashboardLink> quickStart;

  /// Chart panels shown first, in a two-column grid on wide screens.
  final List<Widget> charts;
  final List<DashboardMetric> metrics;
  final String queueTitle;
  final String queueNote;

  /// Static shortcuts: shown when [queueRole] is null or its data cannot be
  /// read.
  final List<DashboardLink> queue;

  /// Canonical role name (e.g. `TEACHER`) whose real records feed the queue
  /// through [dashboardQueueProvider]. Null keeps the static [queue].
  final String? queueRole;
  final List<DashboardGroup> groups;
  final Widget? footer;

  const RoleDashboard({
    super.key,
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.queueTitle,
    required this.queue,
    required this.groups,
    this.quickStart = const [],
    this.queueRole,
    this.queueNote = 'Open',
    this.charts = const [],
    this.footer,
  });

  void _open(BuildContext context, String route, {bool push = false}) {
    if (push) {
      context.push(route);
    } else {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UiPage(
      children: [
        PageHead(kicker: kicker, title: title, subtitle: subtitle),
        if (quickStart.isNotEmpty) ...[
          _QuickStartStrip(
            actions: quickStart,
            onOpen: (link) => _open(context, link.route, push: link.push),
          ),
          const SizedBox(height: 14),
        ],
        if (charts.isNotEmpty) ...[
          AdaptiveGrid(
            columns: 2,
            mediumColumns: 1,
            phoneColumns: 1,
            gap: 14,
            children: charts,
          ),
          const SizedBox(height: 14),
        ],
        AdaptiveGrid(
          phoneColumns: 2,
          children: [
            for (final metric in metrics) _metricCard(context, ref, metric),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          title: queueTitle,
          trailing: PanelNote(queueNote),
          child: _queueBody(context, ref),
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          columns: 3,
          gap: 14,
          children: [
            for (final group in groups)
              Panel(
                title: group.title,
                child: QueueList(
                  items: [
                    for (final link in group.links)
                      QueueItem(
                        icon: link.icon,
                        title: link.label,
                        onTap: () =>
                            _open(context, link.route, push: link.push),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (footer != null) ...[const SizedBox(height: 14), footer!],
      ],
    );
  }

  /// Static shortcut rows (the fallback queue).
  Widget _staticQueue(BuildContext context) => QueueList(
    items: [
      for (final item in queue)
        QueueItem(
          icon: item.icon,
          title: item.label,
          subtitle: item.detail,
          onTap: () => _open(context, item.route, push: item.push),
        ),
    ],
  );

  Widget _queueBody(BuildContext context, WidgetRef ref) {
    final role = queueRole;
    if (role == null) return _staticQueue(context);
    final entries = ref.watch(dashboardQueueProvider(role));
    return entries.when(
      loading: () => const _QueueLoading(),
      error: (_, _) => _staticQueue(context),
      data: (items) {
        if (items.isEmpty) return const _NothingWaiting();
        return QueueList(
          items: [
            for (final item in items)
              QueueItem(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                pill: StatusPill(item.pill, tone: item.tone),
                onTap: () => _open(context, item.route),
              ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    BuildContext context,
    WidgetRef ref,
    DashboardMetric metric,
  ) {
    final count = metric.watch(ref);
    return MetricCard(
      icon: metric.icon,
      label: metric.label,
      value: count.when(
        data: (value) => '$value',
        loading: () => null,
        error: (_, _) => '—',
      ),
      note: count.hasError ? 'Unavailable. Reopen the dashboard to retry.' : metric.note,
      noteTone: count.hasError ? StatusTone.warning : StatusTone.neutral,
      onTap: metric.route == null ? null : () => _open(context, metric.route!),
    );
  }
}

/// "Quick start": the role's three most common tasks as large flat tiles.
class _QuickStartStrip extends StatelessWidget {
  final List<DashboardLink> actions;
  final void Function(DashboardLink link) onOpen;

  const _QuickStartStrip({required this.actions, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'QUICK START',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: AppColors.primary,
            ),
          ),
        ),
        AdaptiveGrid(
          columns: 3,
          mediumColumns: 1,
          phoneColumns: 1,
          children: [
            for (final action in actions)
              _QuickStartTile(action: action, onTap: () => onOpen(action)),
          ],
        ),
      ],
    );
  }
}

class _QuickStartTile extends StatelessWidget {
  final DashboardLink action;
  final VoidCallback onTap;

  const _QuickStartTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.detail == null
          ? action.label
          : '${action.label}. ${action.detail}',
      child: ExcludeSemantics(
        child: UiCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (action.detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.detail!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while the queue records are loading.
class _QueueLoading extends StatelessWidget {
  const _QueueLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Text(
        'Checking what is waiting…',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Friendly empty state for a queue with nothing in it.
class _NothingWaiting extends StatelessWidget {
  const _NothingWaiting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 22,
            color: AppColors.success,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nothing waiting. New items appear here when they need you.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
