import '../../../../core/auth/school_role_access.dart';
import '../../../academics/domain/models/academic_year.dart';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/form_state_persistence.dart';
import '../calendar_providers.dart';
import '../../domain/models/calendar_event.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../../core/navigation/close_form.dart';

// ── Supporting providers ──────────────────────────────────────────────────────

/// Create or edit a calendar event.
/// Pass [existingEvent] to enter edit mode.
class CalendarEventFormPage extends ConsumerStatefulWidget {
  final CalendarEvent? existingEvent;
  final DateTime? initialDate;

  /// When set the editor is embedded (for example in the calendar's side
  /// panel) instead of living in its own route or dialog: closing or saving
  /// calls this with `true` after a save and `false` when dismissed, rather
  /// than popping the navigator.
  final ValueChanged<bool>? onFinished;

  const CalendarEventFormPage({
    this.existingEvent,
    this.initialDate,
    this.onFinished,
    super.key,
  });

  @override
  ConsumerState<CalendarEventFormPage> createState() =>
      _CalendarEventFormPageState();
}

class _CalendarEventFormPageState extends ConsumerState<CalendarEventFormPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final AutoSaveDebouncer _autoSaveDebouncer;

  // ── Form state ────────────────────────────────────────────────────────────
  CalendarEventType _type = CalendarEventType.schoolEvent;
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final Set<DateTime> _additionalDates = {};
  bool _allDay = false;
  String? _classId;
  String? _academicYearId;
  bool _saving = false;
  bool _autoSaving = false;
  DateTime? _lastSavedTime;
  bool _applyToAllClasses = false;

  bool get _isEdit => widget.existingEvent != null;
  String get _formId => _isEdit
      ? 'calendar_event_edit_${widget.existingEvent!.eventId}'
      : 'calendar_event_create';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    _nameCtrl = TextEditingController(text: e?.eventName ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');

    // Initialize auto-save debouncer
    _autoSaveDebouncer = AutoSaveDebouncer(
      onSave: _autoSaveFormState,
      duration: const Duration(seconds: 3),
    );

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
    } else if (widget.initialDate != null) {
      _startDate = DateUtils.dateOnly(widget.initialDate!);
      _endDate = _startDate;
    } else {
      // Load saved form state if not in edit mode
      _loadFormState();
    }
  }

  /// Load saved form state from SharedPreferences
  Future<void> _loadFormState() async {
    try {
      final savedData = await FormStatePersistence.loadFormState(_formId);
      if (savedData != null && mounted) {
        setState(() {
          _nameCtrl.text = savedData['eventName'] ?? '';
          _descCtrl.text = savedData['description'] ?? '';
          _type =
              _parseEventType(savedData['eventType']) ??
              CalendarEventType.schoolEvent;
          _allDay = savedData['allDay'] ?? false;
          if (savedData['startDate'] != null) {
            _startDate = DateTime.parse(savedData['startDate']);
          }
          if (savedData['startTime'] != null) {
            final timeParts = (savedData['startTime'] as String).split(':');
            _startTime = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );
          }
          if (savedData['endDate'] != null) {
            _endDate = DateTime.parse(savedData['endDate']);
          }
          if (savedData['endTime'] != null) {
            final timeParts = (savedData['endTime'] as String).split(':');
            _endTime = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );
          }
          _additionalDates.addAll(
            (savedData['additionalDates'] as List? ?? []).map(
              (d) => DateUtils.dateOnly(DateTime.parse(d as String)),
            ),
          );
          _classId = savedData['classId'];
          _academicYearId = savedData['academicYearId'];
          _applyToAllClasses = savedData['applyToAllClasses'] ?? false;
        });
        developer.log(
          'Form state restored from cache',
          name: 'CalendarEventForm',
        );
      }
    } catch (e) {
      developer.log(
        'Error loading form state',
        name: 'CalendarEventForm',
        error: e,
      );
    }
  }

  /// Parse event type from string
  CalendarEventType? _parseEventType(String? value) {
    if (value == null) return null;
    for (final type in CalendarEventType.values) {
      if (type.toString() == value || type.label == value) {
        return type;
      }
    }
    return null;
  }

  /// Get current form data as map
  Map<String, dynamic> _getFormData() {
    return {
      'additionalDates': _additionalDates
          .map((d) => d.toIso8601String())
          .toList(),
      'eventName': _nameCtrl.text,
      'description': _descCtrl.text,
      'eventType': _type.toString(),
      'allDay': _allDay,
      'startDate': _startDate.toIso8601String(),
      'startTime': '${_startTime.hour}:${_startTime.minute}',
      'endDate': _endDate.toIso8601String(),
      'endTime': '${_endTime.hour}:${_endTime.minute}',
      'classId': _classId,
      'academicYearId': _academicYearId,
      'applyToAllClasses': _applyToAllClasses,
    };
  }

  /// Auto-save form state to SharedPreferences
  Future<void> _autoSaveFormState() async {
    if (_isEdit) return; // Only auto-save for new forms

    setState(() => _autoSaving = true);
    try {
      await FormStatePersistence.saveFormStateWithTimestamp(
        _formId,
        _getFormData(),
      );
      final lastSaved = await FormStatePersistence.getLastSavedTime(_formId);
      if (mounted) {
        setState(() {
          _autoSaving = false;
          _lastSavedTime = lastSaved;
        });
      }
      developer.log('Form auto-saved', name: 'CalendarEventForm');
    } catch (e) {
      developer.log(
        'Error auto-saving form',
        name: 'CalendarEventForm',
        error: e,
      );
      if (mounted) setState(() => _autoSaving = false);
    }
  }

  /// Trigger auto-save on field changes
  void _onFieldChanged() {
    _autoSaveDebouncer.save();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _autoSaveDebouncer.dispose();
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
    if (picked != null) {
      onPicked(picked);
      _onFieldChanged(); // Trigger auto-save
    }
  }

  Future<void> _pickTime({
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      onPicked(picked);
      _onFieldChanged(); // Trigger auto-save
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  /// Close the editor: through [CalendarEventFormPage.onFinished] when
  /// embedded, otherwise by popping the dialog / route that hosts it.
  void _finish(bool saved) {
    final callback = widget.onFinished;
    if (callback != null) {
      callback(saved);
    } else {
      closeForm(context, '/calendar', saved ? true : null);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
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

    _autoSaveDebouncer.cancel();
    setState(() => _saving = true);

    try {
      final actor = ref.read(authProvider).user!;
      final repo = ref.read(calendarRepositoryProvider);

      if (!canManageSchoolCalendar(actor.roleName)) {
        throw const FormatException('Only administrators can manage events.');
      }
      final draft = CalendarEvent(
        eventId: widget.existingEvent?.eventId ?? '',
        classId: _classId,
        createdBy: widget.existingEvent?.createdBy ?? '',
        createdByUser: widget.existingEvent?.createdByUser ?? actor.userId,
        createdByName: actor.username,
        eventName: _nameCtrl.text.trim(),
        eventType: _type,
        description: _descCtrl.text.trim(),
        startTime: start,
        endTime: end,
        allDay: _allDay,
        academicYearId: _academicYearId,
        createdAt: DateTime.now(),
      );
      if (_isEdit) {
        await repo.update(
          eventId: draft.eventId,
          event: draft,
          actorUserId: actor.userId,
          actorRole: actor.roleName,
          previousEvent: widget.existingEvent!,
        );
      } else {
        final classIds = <String?>[_classId];
        if (_applyToAllClasses && _type == CalendarEventType.timetable) {
          final classes = await ref.read(calendarClassesProvider.future);
          if (classes.isEmpty) {
            throw const FormatException('No classes available.');
          }
          classIds
            ..clear()
            ..addAll(classes.map((c) => c['classid'] as String));
        }
        final dates = {DateUtils.dateOnly(_startDate), ..._additionalDates};
        final dayOffset = DateTime.utc(
          end.year,
          end.month,
          end.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
        final events = <CalendarEvent>[];
        for (final date in dates) {
          for (final classId in classIds) {
            events.add(
              draft.copyWith(
                classId: classId,
                startTime: DateTime(
                  date.year,
                  date.month,
                  date.day,
                  start.hour,
                  start.minute,
                  start.second,
                ),
                endTime: DateTime(
                  date.year,
                  date.month,
                  date.day + dayOffset,
                  end.hour,
                  end.minute,
                  end.second,
                ),
              ),
            );
          }
        }
        await repo.createMany(
          events: events,
          actorUserId: actor.userId,
          actorRole: actor.roleName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? 'Event updated successfully'
                  : 'Event created successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Clear saved form state on successful submit
        if (!_isEdit) {
          await FormStatePersistence.clearFormState(_formId);
        }

        if (mounted) _finish(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving event: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
    final user = ref.watch(authProvider).user;
    final classAsync = ref.watch(calendarClassesProvider);
    final yearsAsync = ref.watch(calendarYearsProvider);

    // Only ADMIN can create calendar events
    final canCreateEvent = canManageSchoolCalendar(user?.roleName ?? '');

    if (!canCreateEvent) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: UiEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Calendar events',
          message: 'Only administrators can create calendar events.',
        ),
      );
    }

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(bottom: BorderSide(color: AppColors.border)),
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: _saving ? null : () => _finish(false),
          ),
          title: Text(
            _isEdit ? 'Edit Event' : 'New Calendar Event',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            if (!_isEdit)
              AutoSaveIndicator(
                isSaving: _autoSaving,
                lastSavedTime: _lastSavedTime,
              ),
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
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Event name ─────────────────────────────────
                UiField(
                  label: 'Event name *',
                  child: TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Parents meeting',
                      prefixIcon: Icon(Icons.event),
                    ),
                    onChanged: (_) => _onFieldChanged(),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
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
                      onSelected: (_) {
                        setState(() => _type = t);
                        _onFieldChanged();
                      },
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
                const SizedBox(height: 8),

                // ── Date range info ────────────────────────────
                const InlineGuide(
                  text:
                      'Select a date range (e.g., Monday to Friday) to create recurring events',
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

                if (!_isEdit) ...[
                  const Text(
                    'Additional dates',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'Repeat this event on other dates using the same times and description.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final date in _additionalDates)
                        InputChip(
                          label: Text(_fmtDate(date)),
                          onDeleted: () =>
                              setState(() => _additionalDates.remove(date)),
                        ),
                      ActionChip(
                        label: const Text('Add date'),
                        avatar: const Icon(Icons.add, size: 18),
                        onPressed: () => _pickDate(
                          initial: _startDate,
                          onPicked: (date) => setState(() {
                            if (!DateUtils.isSameDay(date, _startDate)) {
                              _additionalDates.add(DateUtils.dateOnly(date));
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Optional: Class (leave null = school-wide) ──
                _SectionLabel('Class  (leave blank for school-wide event)'),
                const SizedBox(height: 8),
                classAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Could not load classes: $e'),
                  data: (classes) => Column(
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: _applyToAllClasses ? null : _classId,
                        isExpanded: true,
                        decoration: const InputDecoration(
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
                              child: Text(c['classroomname'] as String),
                            ),
                          ),
                        ],
                        onChanged: _applyToAllClasses
                            ? null
                            : (v) => setState(() => _classId = v),
                      ),
                      if (_type == CalendarEventType.timetable) ...[
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('Apply to all classes'),
                          subtitle: const Text(
                            'Create this event for every class',
                          ),
                          value: _applyToAllClasses,
                          onChanged: (v) => setState(() {
                            _applyToAllClasses = v ?? false;
                            if (_applyToAllClasses) _classId = null;
                          }),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ],
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
                    isExpanded: true,
                    decoration: const InputDecoration(
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
                          child: Text(formatAcademicYear(y['academicyear'])),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _academicYearId = v),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Description ────────────────────────────────
                UiField(
                  label: 'Description (optional)',
                  child: TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add any details families or staff should know',
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Submit ─────────────────────────────────────
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(),
                  icon: Icon(_isEdit ? Icons.save : Icons.add),
                  label: Text(_isEdit ? 'Save Changes' : 'Create Event'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
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
    CalendarEventType.termDate => AppColors.primaryDark,
  };
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => FieldLabel(text);
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
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}
