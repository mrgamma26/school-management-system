// lib/widgets/ui_record_list.dart
// Read-only record list used by the oversight screens (corrections, publishing,
// deposit slips, arrangements, reversals, email log): optional metric header,
// search box, status filter chips, table and pager - all built from ui_kit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/app_widgets.dart' show ErrorState, LoadingState;
import '../theme/app_tokens.dart';
import 'ui_kit.dart';

/// Searchable, filterable, client-paged table for a list of [T].
///
/// Place it inside a [UiPage] (it does not scroll by itself). Filter chips are
/// shown when [filters] has more than one entry; the first entry means "all".
class RecordListView<T> extends StatefulWidget {
  final AsyncValue<List<T>> data;
  final VoidCallback onRetry;
  final List<UiColumn> columns;
  final UiTableRow Function(T item) rowOf;
  final String Function(T item) searchText;
  final String searchHint;
  final List<String> filters;
  final bool Function(T item, String filter)? matchesFilter;
  final Widget Function(List<T> items)? header;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final String loadingMessage;
  final int pageSize;

  const RecordListView({
    super.key,
    required this.data,
    required this.onRetry,
    required this.columns,
    required this.rowOf,
    required this.searchText,
    this.searchHint = 'Search',
    this.filters = const [],
    this.matchesFilter,
    this.header,
    this.emptyIcon = Icons.inbox_outlined,
    required this.emptyTitle,
    this.emptyMessage,
    this.loadingMessage = 'Loading…',
    this.pageSize = 25,
  });

  @override
  State<RecordListView<T>> createState() => _RecordListViewState<T>();
}

class _RecordListViewState<T> extends State<RecordListView<T>> {
  final _search = TextEditingController();
  String _query = '';
  late String _filter = widget.filters.isEmpty ? '' : widget.filters.first;
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.data.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: LoadingState(message: widget.loadingMessage),
      ),
      error: (error, _) => ErrorState(error: error, onRetry: widget.onRetry),
      data: (items) {
        if (items.isEmpty) {
          return UiCard(
            child: UiEmptyState(
              icon: widget.emptyIcon,
              title: widget.emptyTitle,
              message: widget.emptyMessage,
            ),
          );
        }
        final query = _query.trim().toLowerCase();
        final matcher = widget.matchesFilter;
        final visible = [
          for (final item in items)
            if ((widget.filters.length < 2 ||
                    _filter == widget.filters.first ||
                    matcher == null ||
                    matcher(item, _filter)) &&
                (query.isEmpty ||
                    widget.searchText(item).toLowerCase().contains(query)))
              item,
        ];
        final pages = (visible.length / widget.pageSize).ceil();
        final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
        final pageItems = PagerBar.slice(visible, page, widget.pageSize);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null) ...[
              widget.header!(items),
              const SizedBox(height: 14),
            ],
            UiToolbar(
              controller: _search,
              searchHint: widget.searchHint,
              onSearch: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
              trailing: [
                if (widget.filters.length > 1)
                  for (final f in widget.filters)
                    FilterChipBox(
                      f,
                      selected: f == _filter,
                      onTap: () => setState(() {
                        _filter = f;
                        _page = 0;
                      }),
                    ),
              ],
            ),
            DataTableCard(
              columns: widget.columns,
              rows: [for (final item in pageItems) widget.rowOf(item)],
              empty: const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No records match your search or filter.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            PagerBar(
              total: visible.length,
              page: page,
              pageSize: widget.pageSize,
              onPage: (p) => setState(() => _page = p),
            ),
          ],
        );
      },
    );
  }
}

/// Plain label/value pair for the little details dialogs.
class DialogDetailList extends StatelessWidget {
  final List<(String, String)> lines;
  const DialogDetailList(this.lines, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [for (final l in lines) DetailLine(l.$1, l.$2)],
  );
}
