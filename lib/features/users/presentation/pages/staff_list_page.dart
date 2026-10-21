import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/can.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/staff.dart';

final _staffListProvider = FutureProvider<List<Staff>>((ref) {
  return UserRepository().listStaff();
});

/// Screen 13 - Staff directory.
class StaffListPage extends ConsumerStatefulWidget {
  const StaffListPage({super.key});

  @override
  ConsumerState<StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends ConsumerState<StaffListPage> {
  static const _pageSize = 25;
  String _query = '';
  int _page = 0;

  Future<void> _add() async {
    await context.push<bool>('/users/staff/new');
    if (mounted) ref.invalidate(_staffListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_staffListProvider);
    final canEdit = ref
        .watch(permissionsProvider)
        .maybeWhen(
          data: (permissions) => permissions.contains('staff:write'),
          orElse: () => false,
        );

    return UiPage(
      children: [
        PageHead(
          kicker: 'People',
          title: 'Staff Directory',
          subtitle: 'Complete staff profiles, roles and employment status.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_staffListProvider),
            ),
            Can(
              permission: 'staff:write',
              child: UiButton(
                'Add Staff',
                icon: Icons.person_add_alt,
                onPressed: _add,
              ),
            ),
          ],
        ),
        UiToolbar(
          searchHint: 'Search by name or employee number',
          onSearch: (v) => setState(() {
            _query = v.trim().toLowerCase();
            _page = 0;
          }),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading staff…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_staffListProvider),
          ),
          data: (staff) {
            if (staff.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.badge_outlined,
                  title: 'No staff members yet',
                  message: 'Add staff members to get started.',
                ),
              );
            }
            final filtered = _query.isEmpty
                ? staff
                : staff
                      .where(
                        (s) =>
                            s.fullName.toLowerCase().contains(_query) ||
                            s.employeeNumber.toLowerCase().contains(_query),
                      )
                      .toList();
            if (filtered.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.search_off,
                  title: 'No matching staff',
                  message: 'Try a different name or employee number.',
                ),
              );
            }

            final pageCount = (filtered.length / _pageSize).ceil();
            final page = _page.clamp(0, pageCount - 1);
            final visible = PagerBar.slice(filtered, page, _pageSize);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTableCard(
                  columns: const [
                    UiColumn('Staff member', flex: 18),
                    UiColumn('Employee no.', flex: 10, hideOnPhone: true),
                    UiColumn('Job title', flex: 11, hideOnPhone: true),
                    UiColumn('Status', flex: 9),
                    UiColumn('', width: 24),
                  ],
                  rows: [
                    for (final s in visible)
                      UiTableRow(
                        [
                          PersonCell(s.fullName, subtitle: s.email),
                          UiCellText(s.employeeNumber),
                          UiCellText(s.jobTitle ?? '—'),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: StatusPill.auto(s.employmentStatus),
                          ),
                          canEdit
                              ? const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: Color(0xFF64758B),
                                )
                              : const SizedBox.shrink(),
                        ],
                        onTap: canEdit
                            ? () async {
                                await context.push<bool>(
                                  '/users/staff/${s.staffId}/edit',
                                  extra: s,
                                );
                                if (mounted) ref.invalidate(_staffListProvider);
                              }
                            : null,
                      ),
                  ],
                ),
                PagerBar(
                  total: filtered.length,
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
}
