import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/guardian.dart';

final _guardianListProvider = FutureProvider<List<Guardian>>((ref) {
  return UserRepository().listGuardians();
});

/// Screen 11 - Guardians directory. Guardians are created during student
/// registration; this page lists them and supports edits.
class GuardianListPage extends ConsumerStatefulWidget {
  const GuardianListPage({super.key});

  @override
  ConsumerState<GuardianListPage> createState() => _GuardianListPageState();
}

class _GuardianListPageState extends ConsumerState<GuardianListPage> {
  static const _pageSize = 25;
  String _query = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_guardianListProvider);
    final canEdit = ref
        .watch(permissionsProvider)
        .maybeWhen(
          data: (permissions) => permissions.contains('guardians:write'),
          orElse: () => false,
        );

    return UiPage(
      children: [
        PageHead(
          kicker: 'People',
          title: 'Guardians',
          subtitle: 'Guardian directory with contact details and linked records.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_guardianListProvider),
            ),
          ],
        ),
        UiToolbar(
          searchHint: 'Search by name or email',
          onSearch: (v) => setState(() {
            _query = v.trim().toLowerCase();
            _page = 0;
          }),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading guardians…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_guardianListProvider),
          ),
          data: (guardians) {
            final filtered = _query.isEmpty
                ? guardians
                : guardians
                      .where(
                        (g) =>
                            g.fullName.toLowerCase().contains(_query) ||
                            (g.email?.toLowerCase().contains(_query) ?? false),
                      )
                      .toList();

            if (filtered.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.family_restroom_outlined,
                  title: 'No guardians found',
                  message:
                      'Guardians are added while registering a student, or try a different search.',
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
                    UiColumn('Guardian', flex: 18),
                    UiColumn('Phone', flex: 10),
                    UiColumn('Gender', flex: 7, hideOnPhone: true),
                    UiColumn('Account', flex: 9, hideOnPhone: true),
                    UiColumn('', width: 24),
                  ],
                  rows: [
                    for (final g in visible)
                      UiTableRow(
                        [
                          PersonCell(
                            g.fullName,
                            subtitle: g.email ?? 'No email on record',
                          ),
                          UiCellText(g.phoneNumber ?? '—'),
                          UiCellText(g.gender),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: g.userId == null
                                ? const StatusPill(
                                    'No login',
                                    tone: StatusTone.neutral,
                                  )
                                : const StatusPill(
                                    'Has login',
                                    tone: StatusTone.success,
                                  ),
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
                                  '/users/guardians/${g.guardianId}/edit',
                                  extra: g,
                                );
                                if (mounted) {
                                  ref.invalidate(_guardianListProvider);
                                }
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
