import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/academic_calendar_repository.dart';
import '../../domain/models/academic_calendar.dart';

final academicCalendarYearsProvider =
    FutureProvider<List<AcademicCalendarYear>>(
      (ref) => AcademicCalendarRepository().listYears(),
    );

/// Screens 18 and 20 - Academic years, each with its Term 1-3 definitions.
class AcademicYearListPage extends ConsumerWidget {
  const AcademicYearListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(academicCalendarYearsProvider);
    final activeRole = ref.watch(activeWorkspaceRoleProvider);
    final user = ref.watch(authProvider).user;
    final canEdit = canManageSchoolCalendar(
      activeRole.isEmpty ? user?.roleName ?? '' : activeRole,
    );

    return UiPage(
      children: [
        PageHead(
          kicker: 'Academics',
          title: 'Academic Years',
          subtitle:
              'One shared school year serving Forms 1 to 4, with three terms.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(academicCalendarYearsProvider),
            ),
            if (canEdit)
              UiButton(
                'Add Year',
                icon: Icons.add_rounded,
                onPressed: () async {
                  await context.push('/academics/years/new');
                  ref.invalidate(academicCalendarYearsProvider);
                },
              ),
          ],
        ),
        years.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading academic years…'),
          ),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(academicCalendarYearsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No academic years configured',
                  message:
                      'Create one school-wide year and enter dates for Term 1, Term 2, and Term 3.',
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final year in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _AcademicYearPanel(
                      year: year,
                      onEdit: !canEdit
                          ? null
                          : () async {
                              await context.push(
                                '/academics/years/${year.id}/edit',
                                extra: year,
                              );
                              ref.invalidate(academicCalendarYearsProvider);
                            },
                      onActivate: !canEdit
                          ? null
                          : () async {
                              await AcademicCalendarRepository().activateYear(
                                year.id,
                              );
                              ref.invalidate(academicCalendarYearsProvider);
                            },
                      onSetTerm: !canEdit
                          ? null
                          : (id) async {
                              await AcademicCalendarRepository().setCurrentTerm(
                                id,
                              );
                              ref.invalidate(academicCalendarYearsProvider);
                            },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AcademicYearPanel extends StatelessWidget {
  final AcademicCalendarYear year;
  final VoidCallback? onEdit;
  final VoidCallback? onActivate;
  final ValueChanged<String>? onSetTerm;

  const _AcademicYearPanel({
    required this.year,
    required this.onEdit,
    required this.onActivate,
    required this.onSetTerm,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: year.name,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (year.isCurrent)
            const StatusPill('Current', tone: StatusTone.success)
          else
            StatusPill.auto(year.status),
          if (!year.isCurrent && onActivate != null)
            UiButton.secondary('Make current', onPressed: onActivate),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatUiDate(year.startDate)} – ${formatUiDate(year.endDate)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64758B),
            ),
          ),
          const SizedBox(height: 12),
          QueueList(
            items: [
              for (final term in year.terms)
                QueueItem(
                  icon: term.isCurrent
                      ? Icons.check_circle_rounded
                      : Icons.event_note_outlined,
                  title: term.name,
                  subtitle:
                      '${formatUiDate(term.startDate)} – ${formatUiDate(term.endDate)}',
                  pill: term.isCurrent
                      ? const StatusPill(
                          'Current term',
                          tone: StatusTone.success,
                        )
                      : (year.isCurrent && onSetTerm != null
                            ? const StatusPill(
                                'Set as current',
                                tone: StatusTone.info,
                              )
                            : null),
                  onTap: year.isCurrent && onSetTerm != null && !term.isCurrent
                      ? () => onSetTerm!(term.id)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
