import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/audit_repository.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

class _AuditFilters {
  final String? action;
  final String? table;
  final DateTime? from;
  final DateTime? to;

  const _AuditFilters({this.action, this.table, this.from, this.to});

  _AuditFilters copyWith({
    Object? action = _sentinel,
    Object? table = _sentinel,
    Object? from = _sentinel,
    Object? to = _sentinel,
  }) => _AuditFilters(
    action: identical(action, _sentinel) ? this.action : action as String?,
    table: identical(table, _sentinel) ? this.table : table as String?,
    from: identical(from, _sentinel) ? this.from : from as DateTime?,
    to: identical(to, _sentinel) ? this.to : to as DateTime?,
  );

  static const _sentinel = Object();
}

class _AuditFiltersNotifier extends Notifier<_AuditFilters> {
  @override
  _AuditFilters build() => const _AuditFilters();

  void update(_AuditFilters filters) => state = filters;
  void reset() => state = const _AuditFilters();
}

final _auditFiltersProvider =
    NotifierProvider<_AuditFiltersNotifier, _AuditFilters>(
      _AuditFiltersNotifier.new,
    );

final _auditLogProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final filters = ref.watch(_auditFiltersProvider);
  final repo = AuditRepository();

  return repo.listAuditLogs(
    action: filters.action,
    tableName: filters.table,
    fromDate: filters.from,
    toDate: filters.to,
    limit: kAuditLogPageSize,
  );
});

final _auditTablesProvider = FutureProvider<List<String>>((ref) async {
  return AuditRepository().listTablesWithAuditEntries();
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// Screen 64 - Audit log viewer (Super User / System Admin only).
/// Supports filtering by action keyword, table name, and date range.
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  static const _pageSize = 25;

  final _actionCtrl = TextEditingController();
  bool _showFilters = false;
  int _page = 0;

  @override
  void dispose() {
    _actionCtrl.dispose();
    super.dispose();
  }

  void _setFilters(_AuditFilters next) {
    _page = 0;
    ref.read(_auditFiltersProvider.notifier).update(next);
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(_auditFiltersProvider);
    final logAsync = ref.watch(_auditLogProvider);
    final tablesAsync = ref.watch(_auditTablesProvider);

    return PageFrame(
      kicker: 'Administration',
      title: 'Audit Log',
      subtitle: 'Who changed what, and when. Entries cannot be edited.',
      actions: [
        UiButton.secondary(
          _showFilters ? 'Hide filters' : 'Filters',
          icon: _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
        UiButton.secondary(
          'Refresh',
          icon: Icons.refresh_rounded,
          onPressed: () => ref.invalidate(_auditLogProvider),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── Filter panel ─────────────────────────────────────────────────
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                title: 'Filter entries',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldGrid(
                      children: [
                        UiField(
                          label: 'Action contains',
                          child: TextField(
                            controller: _actionCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. PAYMENT',
                              prefixIcon: Icon(Icons.search, size: 19),
                            ),
                            onSubmitted: (v) =>
                                _setFilters(filters.copyWith(action: v.trim())),
                          ),
                        ),
                        UiField(
                          label: 'Table',
                          child: tablesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const Text('Tables unavailable.'),
                            data: (tables) => DropdownButtonFormField<String?>(
                              initialValue: filters.table,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All tables'),
                                ),
                                ...tables.map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  _setFilters(filters.copyWith(table: v)),
                            ),
                          ),
                        ),
                        UiField(
                          label: 'From date',
                          child: _DateButton(
                            label: filters.from != null
                                ? formatUiDate(filters.from)
                                : 'Any date',
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: filters.from ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                _setFilters(filters.copyWith(from: d));
                              }
                            },
                          ),
                        ),
                        UiField(
                          label: 'To date',
                          child: _DateButton(
                            label: filters.to != null
                                ? formatUiDate(filters.to)
                                : 'Any date',
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: filters.to ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                _setFilters(filters.copyWith(to: d));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        UiButton(
                          'Apply filters',
                          icon: Icons.search,
                          onPressed: () => _setFilters(
                            filters.copyWith(action: _actionCtrl.text.trim()),
                          ),
                        ),
                        UiButton.secondary(
                          'Clear filters',
                          icon: Icons.clear,
                          onPressed: () {
                            _actionCtrl.clear();
                            _page = 0;
                            ref.read(_auditFiltersProvider.notifier).reset();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── Active filter chips ──────────────────────────────────────────
          if (filters.action != null ||
              filters.table != null ||
              filters.from != null ||
              filters.to != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (filters.action != null)
                    _FilterChip(
                      label: 'action: ${filters.action}',
                      onRemove: () =>
                          _setFilters(filters.copyWith(action: null)),
                    ),
                  if (filters.table != null)
                    _FilterChip(
                      label: 'table: ${filters.table}',
                      onRemove: () =>
                          _setFilters(filters.copyWith(table: null)),
                    ),
                  if (filters.from != null)
                    _FilterChip(
                      label: 'from: ${formatUiDate(filters.from)}',
                      onRemove: () => _setFilters(filters.copyWith(from: null)),
                    ),
                  if (filters.to != null)
                    _FilterChip(
                      label: 'to: ${formatUiDate(filters.to)}',
                      onRemove: () => _setFilters(filters.copyWith(to: null)),
                    ),
                ],
              ),
            ),

          // ── Log table ────────────────────────────────────────────────────
          logAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: LoadingState(message: 'Loading audit log…'),
            ),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(_auditLogProvider),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return const UiCard(
                  child: UiEmptyState(
                    icon: Icons.history_rounded,
                    title: 'No audit log entries match the current filters',
                  ),
                );
              }
              final pages = (entries.length / _pageSize).ceil();
              final page = _page.clamp(0, pages - 1);
              final visible = PagerBar.slice(entries, page, _pageSize);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DataTableCard(
                    columns: const [
                      UiColumn('Action', flex: 16),
                      UiColumn('Actor', flex: 12),
                      UiColumn('Table', flex: 12, hideOnPhone: true),
                      UiColumn('Time', flex: 12, hideOnPhone: true),
                    ],
                    rows: [
                      for (final e in visible)
                        UiTableRow([
                          _actionCell(e['action'] as String),
                          _actorCell(e),
                          UiCellText(e['tablename'] as String),
                          UiCellText(_fmtTs(e['createdat'] as String)),
                        ], onTap: () => _showDetail(context, e)),
                    ],
                  ),
                  PagerBar(
                    total: entries.length,
                    page: page,
                    pageSize: _pageSize,
                    onPage: (p) => setState(() => _page = p),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionCell(String action) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _actionTone(action).background,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            _actionIcon(action),
            size: 16,
            color: _actionTone(action).foreground,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: UiCellText(action, bold: true)),
      ],
    );
  }

  Widget _actorCell(Map<String, dynamic> e) {
    final user = e['systemuser'] as Map?;
    final role = e['actorrole'] as String? ?? '—';
    return PersonCell('${user?['username'] ?? 'System'}', subtitle: role);
  }

  void _showDetail(BuildContext context, Map<String, dynamic> e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              e['action'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            DetailLine('Table', e['tablename'] as String),
            DetailLine('Record ID', e['recordid'] as String? ?? '—'),
            DetailLine('Actor role', e['actorrole'] as String? ?? '—'),
            DetailLine('Reason', e['reason'] as String? ?? '—'),
            DetailLine('Timestamp', _fmtTs(e['createdat'] as String)),
            if (e['previousvalue'] != null) ...[
              const SizedBox(height: 12),
              const FieldLabel('Before'),
              _ValueBox(
                text: e['previousvalue'].toString(),
                tone: StatusTone.danger,
              ),
            ],
            if (e['newvalue'] != null) ...[
              const SizedBox(height: 12),
              const FieldLabel('After'),
              _ValueBox(
                text: e['newvalue'].toString(),
                tone: StatusTone.success,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _fmtTs(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${formatUiDate(d)} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  StatusTone _actionTone(String action) {
    if (action.contains('DELETE') || action.contains('DEACTIVAT')) {
      return StatusTone.danger;
    }
    if (action.contains('CREATE') ||
        action.contains('ENROL') ||
        action.contains('ADD')) {
      return StatusTone.success;
    }
    if (action.contains('UPDATE') ||
        action.contains('EDIT') ||
        action.contains('RESET') ||
        action.contains('CHANGE')) {
      return StatusTone.warning;
    }
    return StatusTone.info;
  }

  IconData _actionIcon(String action) {
    if (action.contains('DELETE') || action.contains('DEACTIVAT')) {
      return Icons.delete_outline;
    }
    if (action.contains('CREATE') || action.contains('ENROL')) {
      return Icons.add_circle_outline;
    }
    if (action.contains('UPDATE') || action.contains('EDIT')) {
      return Icons.edit_outlined;
    }
    if (action.contains('LOGIN')) return Icons.login;
    if (action.contains('PAYMENT')) return Icons.payments_outlined;
    if (action.contains('PERMISSION')) return Icons.admin_panel_settings_outlined;
    return Icons.history;
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _ValueBox extends StatelessWidget {
  final String text;
  final StatusTone tone;
  const _ValueBox({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: SelectableText(
      text,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    ),
  );
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today, size: 16),
    label: Text(label, overflow: TextOverflow.ellipsis),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      alignment: Alignment.centerLeft,
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label, style: const TextStyle(fontSize: 11)),
    deleteIcon: const Icon(Icons.close, size: 14),
    onDeleted: onRemove,
    padding: EdgeInsets.zero,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
