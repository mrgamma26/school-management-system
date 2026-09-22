import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/supabase_client.dart';
import '../../data/calendar_repository.dart';
import '../../domain/models/calendar_event.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/app_widgets.dart';

// ── Supporting providers ──────────────────────────────────────────────────────

final _classesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('class')
      .select('classid, classname')
      .order('classname', ascending: true);
  return List<Map<String, dynamic>>.from(rows as List);
});

final _yearsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

// Fetch the staffid for the currently logged-in user (needed for createdby).
final _myStaffIdProvider = FutureProvider<String>((ref) async {
  final uid = ref.watch(authProvider).user!.userId;
  final row = await supabase
      .from('staff')
      .select('staffid')
      .eq('userid', uid)
      .single();
  return row['staffid'] as String;
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// Create or edit a calendar event.
/// Pass [existingEvent] to enter edit mode.
class CalendarEventFormPage extends ConsumerStatefulWidget {
  final CalendarEvent? existingEvent;

  const CalendarEventFormPage({this.existingEvent, super.key});

  @override
  ConsumerState<CalendarEventFormPage> createState() =>
      _CalendarEventFormPageState();
}

class _CalendarEventFormPageState extends ConsumerState<CalendarEventFormPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  // ── Form state ────────────────────────────────────────────────────────────
  CalendarEventType _type = CalendarEventType.schoolEvent;
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay(
    hour: TimeOfDay.now().hour + 1,
    minute: TimeOfDay.now().minute,
  );
  bool _allDay = false;
  String? _classId;
  String? _academicYearId;
  bool _saving = false;

  bool get _isEdit => widget.existingEvent != null;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    _nameCtrl = TextEditingController(text: e?.eventName ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');

    if (e != null) {
      _type = e.eventType;
      _allDay = e.allDay;
      _startDate = DateTime(
        e.startTime.year,
        e.startTime.month,
        e.startTime.day,
      );
      _startTime = TimeOfDay.fromDateTime(e.startTime);
      _endDate = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
      _endTime = TimeOfDay.fromDateTime(e.endTime);
      _classId = e.classId;
      _academicYearId = e.academicYearId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickTime({
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save(String staffId) async {
    if (!_formKey.currentState!.validate()) return;

    final start = _allDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day)
        : _combine(_startDate, _startTime);
    final end = _allDay
        ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
        : _combine(_endDate, _endTime);

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date/time must be after start date/time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final actor = ref.read(authProvider).user!;
      final repo = CalendarRepository();

      final draft = CalendarEvent(
        eventId: widget.existingEvent?.eventId ?? '',
        classId: _classId,
        createdBy: staffId,
        createdByName: actor.username,
        eventName: _nameCtrl.text.trim(),
        eventType: _type,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        startTime: start,
        endTime: end,
        allDay: _allDay,
        academicYearId: _academicYearId,
        createdAt: DateTime.now(),
      );

      if (_isEdit) {
        await repo.update(
          eventId: widget.existingEvent!.eventId,
          event: draft,
          actorUserId: actor.userId,
          actorRole: actor.roleName,
          previousEvent: widget.existingEvent!,
        );
      } else {
        await repo.create(
          event: draft,
          actorUserId: actor.userId,
          actorRole: actor.roleName,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(_myStaffIdProvider);
    final classAsync = ref.watch(_classesProvider);
    final yearsAsync = ref.watch(_yearsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Event' : 'New Calendar Event'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Could not load your staff profile: $e\n'
            'Only staff accounts can create calendar events.',
          ),
        ),
        data: (staffId) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Event name ─────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Event Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // ── Event type ─────────────────────────────────
              _SectionLabel('Event Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CalendarEventType.values.map((t) {
                  final selected = _type == t;
                  final color = _typeColor(t);
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: selected,
                    selectedColor: color.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: selected ? color : null,
                      fontWeight: selected ? FontWeight.bold : null,
                    ),
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onSelected: (_) => setState(() => _type = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── All-day toggle ─────────────────────────────
              SwitchListTile(
                title: const Text('All day'),
                subtitle: const Text(
                  'Spans the full day — no specific start/end time',
                ),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // ── Start ──────────────────────────────────────
              _SectionLabel('Start'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: _fmtDate(_startDate),
                      icon: Icons.calendar_today,
                      onTap: () => _pickDate(
                        initial: _startDate,
                        onPicked: (d) => setState(() => _startDate = d),
                      ),
                    ),
                  ),
                  if (!_allDay) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateButton(
                        label: _fmtTime(_startTime),
                        icon: Icons.access_time,
                        onTap: () => _pickTime(
                          initial: _startTime,
                          onPicked: (t) => setState(() => _startTime = t),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // ── End ────────────────────────────────────────
              _SectionLabel('End'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: _fmtDate(_endDate),
                      icon: Icons.calendar_today,
                      onTap: () => _pickDate(
                        initial: _endDate,
                        onPicked: (d) => setState(() => _endDate = d),
                      ),
                    ),
                  ),
                  if (!_allDay) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateButton(
                        label: _fmtTime(_endTime),
                        icon: Icons.access_time,
                        onTap: () => _pickTime(
                          initial: _endTime,
                          onPicked: (t) => setState(() => _endTime = t),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // ── Optional: Class (leave null = school-wide) ──
              _SectionLabel('Class  (leave blank for school-wide event)'),
              const SizedBox(height: 8),
              classAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load classes: $e'),
                data: (classes) => DropdownButtonFormField<String?>(
                  initialValue: _classId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.class_),
                    hintText: 'School-wide (all classes)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('School-wide'),
                    ),
                    ...classes.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c['classid'] as String,
                        child: Text(c['classname'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _classId = v),
                ),
              ),
              const SizedBox(height: 16),

              // ── Optional: Academic year ─────────────────────
              _SectionLabel('Academic Year  (optional)'),
              const SizedBox(height: 8),
              yearsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load academic years: $e'),
                data: (years) => DropdownButtonFormField<String?>(
                  initialValue: _academicYearId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                    hintText: 'Not linked to a term',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Not linked'),
                    ),
                    ...years.map(
                      (y) => DropdownMenuItem<String?>(
                        value: y['academicyearid'] as String,
                        child: Text('${y['academicyear']} — ${y['term']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _academicYearId = v),
                ),
              ),
              const SizedBox(height: 16),

              // ── Description ────────────────────────────────
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(staffId),
                icon: Icon(_isEdit ? Icons.save : Icons.add),
                label: Text(_isEdit ? 'Save Changes' : 'Create Event'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(CalendarEventType t) => switch (t) {
    CalendarEventType.publicHoliday => Colors.red.shade600,
    CalendarEventType.exam => Colors.orange.shade700,
    CalendarEventType.timetable => Colors.blue.shade600,
    CalendarEventType.schoolEvent => Colors.green.shade600,
    CalendarEventType.termDate => Colors.purple.shade600,
  };
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: Colors.black87,
    ),
  );
}

class _DateButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
