import '../../../core/auth/school_role_access.dart';
import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/audit_service.dart';
import '../domain/models/calendar_event.dart';

/// Maps Supabase/database errors to [AppException] subtypes.
AppException mapCalendarException(Object error) {
  final text = error.toString().toLowerCase();

  if (text.contains('pgrst202') ||
      text.contains('pgrst204') ||
      text.contains('42703') ||
      text.contains('could not find the function') ||
      text.contains('createdbyuser') ||
      text.contains('schema cache')) {
    return ServerException(
      'Calendar setup is out of date. Apply the latest database migration '
      'and try again.',
    );
  }

  // Permission/auth errors → ForbiddenException
  if (text.contains('permission') ||
      text.contains('42501') ||
      text.contains('denied')) {
    return ForbiddenException(
      'You do not have permission to perform this action.',
    );
  }

  // Not found errors → NotFoundException
  if (text.contains('0 rows') ||
      text.contains('pgrst116') ||
      text.contains('single()') ||
      text.contains('no rows')) {
    return NotFoundException('Resource not found.');
  }

  // Network errors → NetworkException
  if (text.contains('network') ||
      text.contains('socketexception') ||
      text.contains('connection refused') ||
      text.contains('connection reset')) {
    return NetworkException(
      'Network error. Check your connection and try again.',
    );
  }

  // Server/database errors → ServerException
  return ServerException('Something went wrong. Please try again.');
}

/// Data access layer for the [calendarevent] table.
class CalendarRepository {
  static const _table = 'calendarevent';

  static const _select = '''
    eventid, classid, createdby, createdbyuser, eventname, eventtype,
    description, starttime, endtime, allday, academicyearid,
    createdat,
    class(classroomname),
    staff!createdby(firstname, lastname),
    academicyear(academicyear, term)
  ''';

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns all events, sorted by start time ascending.
  Future<List<CalendarEvent>> listAll() async {
    final rows = await supabase
        .from(_table)
        .select(_select)
        .order('starttime', ascending: true);
    return (rows as List).map((r) => CalendarEvent.fromMap(r)).toList();
  }

  /// Returns events overlapping [from]..[to] (inclusive).
  Future<List<CalendarEvent>> listForRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await supabase
        .from(_table)
        .select(_select)
        .gte('endtime', from.toUtc().toIso8601String())
        .lte('starttime', to.toUtc().toIso8601String())
        .order('starttime', ascending: true);
    return (rows as List).map((r) => CalendarEvent.fromMap(r)).toList();
  }

  /// Returns all events for a given [month] and [year].
  Future<List<CalendarEvent>> listForMonth({
    required int year,
    required int month,
  }) async {
    final from = DateTime(year, month, 1);
    final to = DateTime(
      year,
      month + 1,
      1,
    ).subtract(const Duration(microseconds: 1));
    return listForRange(from: from, to: to);
  }

  /// Returns a single event by [eventId].
  /// Throws [NotFoundException] if no event is found.
  /// Throws [AppException] on permission or network errors.
  Future<CalendarEvent> getById(String eventId) async {
    try {
      final row = await supabase
          .from(_table)
          .select(_select)
          .eq('eventid', eventId)
          .single();
      return CalendarEvent.fromMap(row);
    } catch (e) {
      throw mapCalendarException(e);
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Creates a new calendar event and writes an audit log entry.
  /// Throws [AppException] on any database or network error.
  Future<CalendarEvent> create({
    required CalendarEvent event,
    required String actorUserId,
    required String actorRole,
  }) async {
    _requireAdmin(actorRole);
    try {
      final values = event.toInsertMap()
        ..remove('createdby')
        ..['createdbyuser'] = actorUserId;
      final inserted = await supabase
          .from(_table)
          .insert(values)
          .select(_select)
          .single();

      final created = CalendarEvent.fromMap(inserted);

      await AuditService().log(
        userId: actorUserId,
        action: 'CALENDAR_EVENT_CREATED',
        tableName: _table,
        recordId: created.eventId,
        actorRole: actorRole,
        newValue: {
          'eventname': created.eventName,
          'eventtype': created.eventType.value,
          'starttime': created.startTime.toIso8601String(),
          'endtime': created.endTime.toIso8601String(),
        },
      );

      return created;
    } catch (e) {
      throw mapCalendarException(e);
    }
  }

  /// Updates an existing event by [eventId].
  /// Throws [NotFoundException] if the event is not found.
  /// Throws [AppException] on any database or network error.
  Future<CalendarEvent> update({
    required String eventId,
    required CalendarEvent event,
    required String actorUserId,
    required String actorRole,
    required CalendarEvent previousEvent,
  }) async {
    _requireAdmin(actorRole);
    try {
      final updated = await supabase
          .from(_table)
          .update(
            event.toInsertMap()
              ..remove('createdby')
              ..remove('createdbyuser'),
          )
          .eq('eventid', eventId)
          .select(_select)
          .single();

      final result = CalendarEvent.fromMap(updated);

      await AuditService().log(
        userId: actorUserId,
        action: 'CALENDAR_EVENT_UPDATED',
        tableName: _table,
        recordId: eventId,
        actorRole: actorRole,
        previousValue: {
          'eventname': previousEvent.eventName,
          'eventtype': previousEvent.eventType.value,
          'starttime': previousEvent.startTime.toIso8601String(),
        },
        newValue: {
          'eventname': result.eventName,
          'eventtype': result.eventType.value,
          'starttime': result.startTime.toIso8601String(),
        },
      );

      return result;
    } catch (e) {
      throw mapCalendarException(e);
    }
  }

  /// Deletes an event by [eventId].
  Future<void> delete({
    required String eventId,
    required String actorUserId,
    required String actorRole,
    required String eventName,
  }) async {
    _requireAdmin(actorRole);
    await supabase.from(_table).delete().eq('eventid', eventId);

    await AuditService().log(
      userId: actorUserId,
      action: 'CALENDAR_EVENT_DELETED',
      tableName: _table,
      recordId: eventId,
      actorRole: actorRole,
      previousValue: {'eventname': eventName},
    );
  }

  // ── Lookup Data ───────────────────────────────────────────────────────────

  /// Returns all classes sorted by name.
  Future<List<Map<String, dynamic>>> listClasses() async {
    final rows = await supabase
        .from('class')
        .select('classid, classroomname')
        .order('classroomname', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Returns all academic years sorted by year descending.
  Future<List<Map<String, dynamic>>> listAcademicYears() async {
    final rows = await supabase
        .from('academicyear')
        .select('academicyearid, academicyear, term')
        .order('academicyear', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  void _requireAdmin(String role) {
    if (!canManageSchoolCalendar(role)) {
      throw ForbiddenException(
        'Only administrators can manage calendar events.',
      );
    }
  }

  /// One insert keeps a selection of dates atomic: all succeed or none do.
  Future<void> createMany({
    required List<CalendarEvent> events,
    required String actorUserId,
    required String actorRole,
  }) async {
    _requireAdmin(actorRole);
    if (events.isEmpty) {
      throw const FormatException('Select at least one date.');
    }
    try {
      await supabase.rpc(
        'create_calendar_events',
        params: {'events': events.map((e) => e.toInsertMap()).toList()},
      );
    } catch (e) {
      throw mapCalendarException(e);
    }
  }
}
