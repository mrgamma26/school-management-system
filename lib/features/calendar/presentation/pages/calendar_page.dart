import '../calendar_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/calendar_repository.dart';
import '../../domain/models/calendar_event.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/auth/school_role_access.dart';
import 'calendar_event_form_page.dart';
import '../../../../widgets/skeleton_loader.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// School-wide academic calendar.
/// All roles can view. Administrator and Super User see a FAB to add events.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _openEditor(DateTime day) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 680,
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: CalendarEventFormPage(initialDate: day),
        ),
      ),
    );
    if (saved == true && mounted) ref.invalidate(calendarMonthProvider);
  }

  void _showDayDetails(
    DateTime day,
    List<CalendarEvent> events, {
    required bool canManage,
  }) {
    final dayEvents = _eventsForDay(events, day);
    final localizations = MaterialLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.formatFullDate(day)),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dayEvents.isEmpty) const Text('No events on this day.'),
                for (final event in dayEvents) ...[
                  Text(
                    event.eventName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(event.eventType.label),
                  Text(
                    '${localizations.formatMediumDate(event.startTime)} '
                    '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(event.startTime))}'
                    ' – ${localizations.formatMediumDate(event.endTime)} '
                    '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(event.endTime))}',
                  ),
                  if (event.allDay) const Text('All day'),
                  const SizedBox(height: 8),
                  SelectableText(
                    event.description?.isNotEmpty == true
                        ? event.description!
                        : 'No description provided.',
                  ),
                  if (canManage)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              final saved = await context.push<bool>(
                                '/calendar/${event.eventId}/edit',
                              );
                              if (saved == true && mounted) {
                                ref.invalidate(
                                  calendarMonthProvider((
                                    year: _focusedMonth.year,
                                    month: _focusedMonth.month,
                                  )),
                                );
                              }
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final confirmed = await _confirmDelete(event);
                              if (confirmed && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 28),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.eventName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final actor = ref.read(authProvider).user;
    if (actor == null) return false;
    try {
      await CalendarRepository().delete(
        eventId: event.eventId,
        actorUserId: actor.userId,
        actorRole: actor.roleName,
        eventName: event.eventName,
      );
      ref.invalidate(
        calendarMonthProvider((
          year: _focusedMonth.year,
          month: _focusedMonth.month,
        )),
      );
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete event: $error')),
        );
      }
      return false;
    }
  }

  void _prevMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    _selectedDay = null;
  });

  void _nextMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    _selectedDay = null;
  });

  List<CalendarEvent> _eventsForDay(List<CalendarEvent> all, DateTime day) {
    return all.where((e) {
      final s = e.startTime;
      final end = e.endTime;
      final d = DateTime(day.year, day.month, day.day);
      final start0 = DateTime(s.year, s.month, s.day);
      final end0 = DateTime(end.year, end.month, end.day);
      return !d.isBefore(start0) && !d.isAfter(end0);
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final args = (year: _focusedMonth.year, month: _focusedMonth.month);
    final async = ref.watch(calendarMonthProvider(args));
    final user = ref.watch(authProvider).user;

    // Only ADMIN can create events; others can view
    final canCreateEvent = canManageSchoolCalendar(user?.roleName ?? '');
    // Only admins can manage (edit/delete) events
    final canManage = canCreateEvent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Calendar'),
        actions: [
          if (_selectedDay != null)
            IconButton(
              icon: const Icon(Icons.event_note),
              tooltip: 'View day events',
              onPressed: () => _showDayDetails(
                _selectedDay!,
                async.asData?.value ?? [],
                canManage: canManage,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedMonth = DateTime(now.year, now.month);
                _selectedDay = DateTime(now.year, now.month, now.day);
              });
            },
          ),
        ],
      ),
      floatingActionButton: canCreateEvent
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add Event'),
              onPressed: () => _openEditor(_selectedDay ?? DateTime.now()),
            )
          : null,
      body: async.when(
        loading: () => Column(
          children: [
            _Legend(),
            const Divider(height: 1),
            _MonthHeaderSkeleton(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SkeletonCard(height: 80),
                  ),
                ),
              ),
            ),
          ],
        ),
        error: (e, _) => Center(child: Text('Error loading calendar: $e')),
        data: (events) => Column(
          children: [
            // ── Legend ────────────────────────────────────────
            _Legend(),
            const Divider(height: 1),

            // ── Month header + navigation ──────────────────────
            _MonthHeader(
              focusedMonth: _focusedMonth,
              onPrev: _prevMonth,
              onNext: _nextMonth,
            ),

            // ── Day-of-week labels ─────────────────────────────
            _WeekdayRow(),

            // ── Month grid (non-scrollable, fixed height) ──────
            SizedBox(
              height: 280,
              child: _MonthGrid(
                focusedMonth: _focusedMonth,
                events: events,
                selectedDay: _selectedDay,
                eventsForDay: _eventsForDay,
                isSameDay: _isSameDay,
                onDayTap: (day) {
                  setState(() => _selectedDay = day);
                  _showDayDetails(day, events, canManage: canManage);
                },
                onDayLongPress: (day) =>
                    _showDayDetails(day, events, canManage: canManage),
              ),
            ),

            const Divider(height: 1),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: CalendarEventType.values.map((t) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _eventColor(t),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(t.label, style: const TextStyle(fontSize: 11)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Month header ──────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final DateTime focusedMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.focusedMonth,
    required this.onPrev,
    required this.onNext,
  });

  static const _months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Expanded(
            child: Text(
              '${_months[focusedMonth.month]} ${focusedMonth.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

// ── Weekday row ───────────────────────────────────────────────────────────────

class _WeekdayRow extends StatelessWidget {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _days
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: (d == 'Sat' || d == 'Sun')
                        ? Colors.red.shade300
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Month grid ────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final List<CalendarEvent> events;
  final DateTime? selectedDay;
  final List<CalendarEvent> Function(List<CalendarEvent>, DateTime)
  eventsForDay;
  final bool Function(DateTime, DateTime) isSameDay;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onDayLongPress;

  const _MonthGrid({
    required this.focusedMonth,
    required this.events,
    required this.selectedDay,
    required this.eventsForDay,
    required this.isSameDay,
    required this.onDayTap,
    required this.onDayLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // First day of month, adjusted to Monday-start grid
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    // weekday: 1=Mon … 7=Sun; offset so Mon is column 0
    final startOffset = firstDay.weekday - 1;
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        // The calendar has a fixed display height. On wide browser windows a
        // square cell would be wider than the entire grid is tall, clipping
        // all but the first week. Size rows from the available height instead.
        final cellWidth = constraints.maxWidth / 7;
        final cellHeight = constraints.maxHeight / rows;

        return GridView.builder(
          shrinkWrap: false,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: rows * 7,
          itemBuilder: (context, index) {
            final dayNumber = index - startOffset + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final day = DateTime(
              focusedMonth.year,
              focusedMonth.month,
              dayNumber,
            );
            final dayEvents = eventsForDay(events, day);
            final hasEvents = dayEvents.isNotEmpty;
            final eventColor = hasEvents
                ? _eventColor(dayEvents.first.eventType)
                : Theme.of(context).colorScheme.primary;
            final isToday = isSameDay(day, today);
            final isSelected =
                selectedDay != null && isSameDay(day, selectedDay!);
            final isWeekend = day.weekday >= 6;

            return GestureDetector(
              key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
              onTap: () => onDayTap(day),
              onLongPress: () => onDayLongPress(day),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : hasEvents
                      ? eventColor.withValues(alpha: 0.18)
                      : isToday
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: hasEvents
                      ? Border.all(color: eventColor, width: 1.5)
                      : isToday && !isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isWeekend
                            ? Colors.red.shade400
                            : null,
                      ),
                    ),
                    // Dot indicators — up to 3
                    if (dayEvents.isNotEmpty)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 2,
                        children: dayEvents
                            .take(3)
                            .map(
                              (e) => Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : _eventColor(e.eventType),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Day event list ─────────────────────────────────────────────────────────────

// Retained for the alternate split-pane calendar layout.
// ignore: unused_element
class _DayEventList extends ConsumerWidget {
  final DateTime? selectedDay;
  final List<CalendarEvent> events;
  final bool canManage;
  final VoidCallback onDeleted;
  final ValueChanged<CalendarEvent> onEdit;

  const _DayEventList({
    required this.selectedDay,
    required this.events,
    required this.canManage,
    required this.onDeleted,
    required this.onEdit,
  });

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedDay == null) {
      return const Center(
        child: Text(
          'Tap a day to see events',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final label =
        '${selectedDay!.day} ${_months[selectedDay!.month]} ${selectedDay!.year}';

    if (events.isEmpty) {
      return Column(
        children: [
          _DayHeader(label: label),
          const Expanded(
            child: Center(
              child: Text(
                'No events on this day',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayHeader(label: label),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = events[i];
              return _EventCard(
                event: e,
                canManage: canManage,
                onEdit: () => onEdit(e),
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Event'),
                      content: Text(
                        'Delete "${e.eventName}"? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;

                  final actor = ref.read(authProvider).user!;
                  await CalendarRepository().delete(
                    eventId: e.eventId,
                    actorUserId: actor.userId,
                    actorRole: actor.roleName,
                    eventName: e.eventName,
                  );
                  onDeleted();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

// ── Event card ─────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.eventType);
    final timeLabel = event.allDay
        ? 'All day'
        : '${_fmt(event.startTime)} – ${_fmt(event.endTime)}';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showEventDetailsDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colour accent bar
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Type chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              event.eventType.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (event.className != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                event.className!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (canManage) ...[
                            InkWell(
                              onTap: onEdit,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: onDelete,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.eventName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (event.description != null &&
                          event.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'By ${event.createdByName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.touch_app,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Tap for details',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetailsDialog(BuildContext context) {
    final color = _eventColor(event.eventType);
    final dateFormat = _formatDateRange(event.startTime, event.endTime);
    final timeLabel = event.allDay
        ? 'All day event'
        : '${_fmt(event.startTime)} – ${_fmt(event.endTime)}';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.eventType.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.eventName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: dateFormat,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: timeLabel,
                    ),
                    if (event.className != null) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.class_,
                        label: 'Class',
                        value: event.className!,
                      ),
                    ],
                    if (event.description != null &&
                        event.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.notes,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Description',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Created by ${event.createdByName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canManage) ...[
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onEdit();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${start.day} ${months[start.month]} ${start.year}';
    }

    return '${start.day} ${months[start.month]} – ${end.day} ${months[end.month]} ${end.year}';
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// Detail row widget for the dialog
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Colour helper ─────────────────────────────────────────────────────────────

Color _eventColor(CalendarEventType type) => switch (type) {
  CalendarEventType.publicHoliday => Colors.red.shade600,
  CalendarEventType.exam => Colors.orange.shade700,
  CalendarEventType.timetable => Colors.blue.shade600,
  CalendarEventType.schoolEvent => Colors.green.shade600,
  CalendarEventType.termDate => Colors.purple.shade600,
};

// ── Skeleton loaders for loading states ────────────────────────────────────────

class _MonthHeaderSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SkeletonLine(height: 24, width: 100),
          const SizedBox(width: 8),
          SkeletonLine(height: 24, width: 80),
        ],
      ),
    );
  }
}
