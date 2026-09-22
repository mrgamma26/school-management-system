import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

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
}

final _auditFiltersProvider =
    NotifierProvider<_AuditFiltersNotifier, _AuditFilters>(
      _AuditFiltersNotifier.new,
    );

final _auditLogProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final filters = ref.watch(_auditFiltersProvider);

  // Start with filter builder — apply WHERE clauses BEFORE order/limit
  var q = supabase
      .from('auditlog')
      .select(
        'auditid, action, tablename, recordid, actorrole, reason, '
        'previousvalue, newvalue, createdat, '
        'systemuser(username)',
      );

  if (filters.action != null && filters.action!.isNotEmpty) {
    q = q.ilike('action', '%${filters.action}%');
  }
  if (filters.table != null && filters.table!.isNotEmpty) {
    q = q.eq('tablename', filters.table!);
  }
  if (filters.from != null) {
    q = q.gte('createdat', filters.from!.toIso8601String());
  }
  if (filters.to != null) {
    q = q.lte('createdat', filters.to!.toIso8601String());
  }

  // Apply order + limit last
  final rows = await q.order('createdat', ascending: false).limit(200);

  return List<Map<String, dynamic>>.from(rows as List);
});

// Distinct table names for the filter dropdown
final _auditTablesProvider = FutureProvider<List<String>>((ref) async {
  final rows = await supabase.from('auditlog').select('tablename');
  final names =
      (rows as List).map((r) => r['tablename'] as String).toSet().toList()
        ..sort();
  return names;
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// Audit log viewer — Super User / System Admin only.
/// Supports filtering by action keyword, table name, and date range.
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  final _actionCtrl = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _actionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(_auditFiltersProvider);
    final logAsync = ref.watch(_auditLogProvider);
    final tablesAsync = ref.watch(_auditTablesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filters',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_auditLogProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter panel ─────────────────────────────────────────────────
          if (_showFilters)
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Action keyword
                    TextField(
                      controller: _actionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Action contains…',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (v) =>
                          ref.read(_auditFiltersProvider.notifier).state =
                              filters.copyWith(action: v.trim()),
                    ),
                    const SizedBox(height: 8),
                    // Table filter
                    tablesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (tables) => DropdownButtonFormField<String?>(
                        initialValue: filters.table,
                        decoration: const InputDecoration(
                          labelText: 'Table',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All tables'),
                          ),
                          ...tables.map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          ),
                        ],
                        onChanged: (v) =>
                            ref.read(_auditFiltersProvider.notifier).state =
                                filters.copyWith(table: v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Date range
                    Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: filters.from != null
                                ? _fmt(filters.from!)
                                : 'From date',
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: filters.from ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                ref.read(_auditFiltersProvider.notifier).state =
                                    filters.copyWith(from: d);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DateButton(
                            label: filters.to != null
                                ? _fmt(filters.to!)
                                : 'To date',
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: filters.to ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                ref.read(_auditFiltersProvider.notifier).state =
                                    filters.copyWith(to: d);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          tooltip: 'Clear filters',
                          onPressed: () {
                            _actionCtrl.clear();
                            ref.read(_auditFiltersProvider.notifier).state =
                                const _AuditFilters();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            ref
                                .read(_auditFiltersProvider.notifier)
                                .state = filters.copyWith(
                              action: _actionCtrl.text.trim(),
                            ),
                        icon: const Icon(Icons.search),
                        label: const Text('Apply Filters'),
                      ),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  if (filters.action != null)
                    _FilterChip(
                      label: 'action: ${filters.action}',
                      onRemove: () =>
                          ref.read(_auditFiltersProvider.notifier).state =
                              filters.copyWith(action: null),
                    ),
                  if (filters.table != null)
                    _FilterChip(
                      label: 'table: ${filters.table}',
                      onRemove: () =>
                          ref.read(_auditFiltersProvider.notifier).state =
                              filters.copyWith(table: null),
                    ),
                  if (filters.from != null)
                    _FilterChip(
                      label: 'from: ${_fmt(filters.from!)}',
                      onRemove: () =>
                          ref.read(_auditFiltersProvider.notifier).state =
                              filters.copyWith(from: null),
                    ),
                  if (filters.to != null)
                    _FilterChip(
                      label: 'to: ${_fmt(filters.to!)}',
                      onRemove: () =>
                          ref.read(_auditFiltersProvider.notifier).state =
                              filters.copyWith(to: null),
                    ),
                ],
              ),
            ),

          // ── Log list ─────────────────────────────────────────────────────
          Expanded(
            child: logAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load audit log.\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No audit log entries match the current filters.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final user = e['systemuser'] as Map?;
                    final action = e['action'] as String;
                    final table = e['tablename'] as String;
                    final role = e['actorrole'] as String? ?? '—';
                    final ts = _fmtTs(e['createdat'] as String);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _actionColor(action),
                          radius: 20,
                          child: Icon(
                            _actionIcon(action),
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          action,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user?['username'] ?? 'System'}  •  $role',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Table: $table'
                              '${e['recordid'] != null ? '  •  ID: ${(e['recordid'] as String).substring(0, 8)}…' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          ts,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        isThreeLine: true,
                        onTap: () => _showDetail(context, e),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              e['action'] as String,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _DetailRow('Table', e['tablename'] as String),
            _DetailRow('Record ID', e['recordid'] as String? ?? '—'),
            _DetailRow('Actor Role', e['actorrole'] as String? ?? '—'),
            _DetailRow('Reason', e['reason'] as String? ?? '—'),
            _DetailRow('Timestamp', _fmtTs(e['createdat'] as String)),
            if (e['previousvalue'] != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Before:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e['previousvalue'].toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
            if (e['newvalue'] != null) ...[
              const SizedBox(height: 8),
              const Text(
                'After:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e['newvalue'].toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtTs(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Color _actionColor(String action) {
    if (action.contains('DELETE') || action.contains('DEACTIVAT')) {
      return Colors.red;
    }
    if (action.contains('CREATE') ||
        action.contains('ENROL') ||
        action.contains('ADD')) {
      return Colors.green;
    }
    if (action.contains('UPDATE') ||
        action.contains('EDIT') ||
        action.contains('RESET') ||
        action.contains('CHANGE')) {
      return Colors.orange;
    }
    if (action.contains('LOGIN') || action.contains('AUTH')) {
      return Colors.blue;
    }
    return Colors.blueGrey;
  }

  IconData _actionIcon(String action) {
    if (action.contains('DELETE') || action.contains('DEACTIVAT')) {
      return Icons.delete;
    }
    if (action.contains('CREATE') || action.contains('ENROL')) {
      return Icons.add_circle;
    }
    if (action.contains('UPDATE') || action.contains('EDIT')) {
      return Icons.edit;
    }
    if (action.contains('LOGIN')) return Icons.login;
    if (action.contains('PAYMENT')) return Icons.payments;
    if (action.contains('PERMISSION')) return Icons.admin_panel_settings;
    return Icons.history;
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onRemove,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}
