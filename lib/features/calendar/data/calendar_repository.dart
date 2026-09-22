import '../../../core/database/supabase_client.dart';
import '../../../core/services/audit_service.dart';
import '../domain/models/calendar_event.dart';

/// Data access layer for the [calendarevent] table.
class CalendarRepository {
  static const _table = 'calendarevent';

  static const _select = '''
    eventid, classid, createdby, eventname, eventtype,
    description, starttime, endtime, allday, academicyearid,
    createdat,
    class(classname),
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

  /// Returns events whose [starttime] falls within [from]..[to] (inclusive).
  Future<List<CalendarEvent>> listForRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await supabase
        .from(_table)
        .select(_select)
        .gte('starttime', from.toUtc().toIso8601String())
        .lte('starttime', to.toUtc().toIso8601String())
        .order('starttime', ascending: true);
    return (rows as List).map((r) => CalendarEvent.fromMap(r)).toList();
  }

  /// Returns all events for a given [month] and [year].
  Future<List<CalendarEvent>> listForMonth({
    required int year,
    required int month,
  }) async {
    final from = DateTime.utc(year, month, 1);
    final to   = DateTime.utc(year, month + 1, 1)
        .subtract(const Duration(seconds: 1));
    return listForRange(from: from, to: to);
  }

  /// Returns a single event by [eventId].
  Future<CalendarEvent> getById(String eventId) async {
    final row = await supabase
        .from(_table)
        .select(_select)
        .eq('eventid', eventId)
        .single();
    return CalendarEvent.fromMap(row);
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Creates a new calendar event and writes an audit log entry.
  Future<CalendarEvent> create({
    required CalendarEvent event,
    required String actorUserId,
    required String actorRole,
  }) async {
    final inserted = await supabase
        .from(_table)
        .insert(event.toInsertMap())
        .select(_select)
        .single();

    final created = CalendarEvent.fromMap(inserted);

    await AuditService().log(
      userId:   actorUserId,
      action:   'CALENDAR_EVENT_CREATED',
      tableName: _table,
      recordId: created.eventId,
      actorRole: actorRole,
      newValue: {
        'eventname': created.eventName,
        'eventtype': created.eventType.value,
        'starttime': created.startTime.toIso8601String(),
        'endtime':   created.endTime.toIso8601String(),
      },
    );

    return created;
  }

  /// Updates an existing event by [eventId].
  Future<CalendarEvent> update({
    required String eventId,
    required CalendarEvent event,
    required String actorUserId,
    required String actorRole,
    required CalendarEvent previousEvent,
  }) async {
    final updated = await supabase
        .from(_table)
        .update(event.toInsertMap())
        .eq('eventid', eventId)
        .select(_select)
        .single();

    final result = CalendarEvent.fromMap(updated);

    await AuditService().log(
      userId:   actorUserId,
      action:   'CALENDAR_EVENT_UPDATED',
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
  }

  /// Deletes an event by [eventId].
  Future<void> delete({
    required String eventId,
    required String actorUserId,
    required String actorRole,
    required String eventName,
  }) async {
    await supabase.from(_table).delete().eq('eventid', eventId);

    await AuditService().log(
      userId:   actorUserId,
      action:   'CALENDAR_EVENT_DELETED',
      tableName: _table,
      recordId: eventId,
      actorRole: actorRole,
      previousValue: {'eventname': eventName},
    );
  }
}
