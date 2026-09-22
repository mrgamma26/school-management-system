import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/calendar_repository.dart';
import '../../domain/models/calendar_event.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/app_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _calendarMonthProvider =
    FutureProvider.family<List<CalendarEvent>, ({int year, int month})>((
      ref,
      args,
    ) async {
      final repo = CalendarRepository();
      return repo.listForMonth(year: args.year, month: args.month);
    });

// ── Page ──────────────────────────────────────────────────────────────────────

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

  bool get _canManage {
    final role = ref.read(authProvider).user?.roleName.toUpperCase() ?? '';
    return role == 'SYSTEM_ADMIN' ||
        role == 'SUPER_USER' ||
        role == 'ADMINISTRATOR' ||
        role == 'REGISTRAR';
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
    final async = ref.watch(_calendarMonthProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Calendar'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
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
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add Event'),
              onPressed: () async {
                final result = await context.push<bool>('/calendar/new');
                if (result == true) {
                  ref.invalidate(_calendarMonthProvider(args));
                }
              },
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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

            // ── Month grid ────────────────────────────────────
            _MonthGrid(
              focusedMonth: _focusedMonth,
              events: events,
              selectedDay: _selectedDay,
              eventsForDay: _eventsForDay,
              isSameDay: _isSameDay,
              onDayTap: (day) => setState(() => _selectedDay = day),
            ),

            const Divider(height: 1),

            // ── Event list for selected day ────────────────────
            Expanded(
              child: _DayEventList(
                selectedDay: _selectedDay,
                events: _selectedDay != null
                    ? _eventsForDay(events, _selectedDay!)
                    : [],
                canManage: _canManage,
                onDeleted: () => ref.invalidate(_calendarMonthProvider(args)),
                onEdit: (e) async {
                  final result = await context.push<bool>(
                    '/calendar/${e.eventId}/edit',
                  );
                  if (result == true) {
                    ref.invalidate(_calendarMonthProvider(args));
                  }
                },
              ),
            ),
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

  const _MonthGrid({
    required this.focusedMonth,
    required this.events,
    required this.selectedDay,
    required this.eventsForDay,
    required this.isSameDay,
    required this.onDayTap,
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNumber = index - startOffset + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final day = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
        final dayEvents = eventsForDay(events, day);
        final isToday = isSameDay(day, today);
        final isSelected = selectedDay != null && isSameDay(day, selectedDay!);
        final isWeekend = day.weekday >= 6;

        return GestureDetector(
          onTap: () => onDayTap(day),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : isToday
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
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
  }
}

// ── Day event list ─────────────────────────────────────────────────────────────

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
                    Text(
                      'By ${event.createdByName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Colour helper ─────────────────────────────────────────────────────────────

Color _eventColor(CalendarEventType type) => switch (type) {
  CalendarEventType.publicHoliday => Colors.red.shade600,
  CalendarEventType.exam => Colors.orange.shade700,
  CalendarEventType.timetable => Colors.blue.shade600,
  CalendarEventType.schoolEvent => Colors.green.shade600,
  CalendarEventType.termDate => Colors.purple.shade600,
};
