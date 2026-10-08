import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/calendar/domain/models/calendar_event.dart';

void main() {
  group('CalendarEventType', () {
    test('fromString maps each DB value to enum variant', () {
      expect(
        CalendarEventType.fromString('PUBLIC_HOLIDAY'),
        CalendarEventType.publicHoliday,
      );
      expect(CalendarEventType.fromString('EXAM'), CalendarEventType.exam);
      expect(
        CalendarEventType.fromString('TIMETABLE'),
        CalendarEventType.timetable,
      );
      expect(
        CalendarEventType.fromString('SCHOOL_EVENT'),
        CalendarEventType.schoolEvent,
      );
      expect(
        CalendarEventType.fromString('TERM_DATE'),
        CalendarEventType.termDate,
      );
    });

    test('fromString falls back to schoolEvent for unknown values', () {
      expect(
        CalendarEventType.fromString('UNKNOWN'),
        CalendarEventType.schoolEvent,
      );
      expect(CalendarEventType.fromString(''), CalendarEventType.schoolEvent);
    });

    test('all variants have non-empty value and label', () {
      for (final type in CalendarEventType.values) {
        expect(type.value, isNotEmpty);
        expect(type.label, isNotEmpty);
      }
    });

    test('value round-trips through fromString', () {
      for (final type in CalendarEventType.values) {
        expect(CalendarEventType.fromString(type.value), type);
      }
    });
  });

  group('CalendarEvent.fromMap', () {
    final baseMap = {
      'eventid': 'evt-001',
      'classid': null,
      'class': null,
      'createdby': 'staff-001',
      'staff': {'firstname': 'Grace', 'lastname': 'Nyirenda'},
      'academicyear': null,
      'academicyearid': null,
      'eventname': 'End of Term Assembly',
      'eventtype': 'SCHOOL_EVENT',
      'description': 'Full school assembly to close Term 1.',
      'starttime': '2024-03-20T08:00:00.000Z',
      'endtime': '2024-03-20T10:00:00.000Z',
      'allday': false,
      'createdat': '2024-03-01T12:00:00.000Z',
    };

    test('parses required fields correctly', () {
      final e = CalendarEvent.fromMap(baseMap);
      expect(e.eventId, 'evt-001');
      expect(e.createdBy, 'staff-001');
      expect(e.eventName, 'End of Term Assembly');
      expect(e.eventType, CalendarEventType.schoolEvent);
      expect(e.allDay, isFalse);
      expect(e.description, isNotNull);
    });

    test('createdByName is assembled from staff join', () {
      final e = CalendarEvent.fromMap(baseMap);
      expect(e.createdByName, 'Grace Nyirenda');
    });

    test('an admin author does not require a staff record', () {
      final e = CalendarEvent.fromMap({
        ...baseMap,
        'createdby': null,
        'staff': null,
        'createdbyuser': 'admin-user',
      });
      expect(e.createdByUser, 'admin-user');
      expect(e.toInsertMap()['createdbyuser'], 'admin-user');
      expect(e.toInsertMap().containsKey('createdby'), isFalse);
      expect(e.copyWith(eventName: 'Updated').createdByUser, 'admin-user');
    });

    test('classId and className are null for school-wide events', () {
      final e = CalendarEvent.fromMap(baseMap);
      expect(e.classId, isNull);
      expect(e.className, isNull);
    });

    test('parses classId and className from join when present', () {
      final map = {
        ...baseMap,
        'classid': 'cls-002',
        'class': {'classname': 'Grade 5A'},
      };
      final e = CalendarEvent.fromMap(map);
      expect(e.classId, 'cls-002');
      expect(e.className, 'Grade 5A');
    });

    test('academicYearLabel is assembled when join present', () {
      final map = {
        ...baseMap,
        'academicyearid': 'yr-001',
        'academicyear': {'academicyear': '2024', 'term': 'TERM_1'},
      };
      final e = CalendarEvent.fromMap(map);
      expect(e.academicYearLabel, '2024/2025');
    });

    test('startTime and endTime are converted to local', () {
      final e = CalendarEvent.fromMap(baseMap);
      expect(e.startTime, isA<DateTime>());
      expect(e.endTime.isAfter(e.startTime), isTrue);
    });

    test('toInsertMap excludes eventId and joined fields', () {
      final e = CalendarEvent.fromMap(baseMap);
      final insert = e.toInsertMap();
      expect(insert.containsKey('eventid'), isFalse);
      expect(insert.containsKey('class'), isFalse);
      expect(insert.containsKey('staff'), isFalse);
      expect(insert['eventname'], 'End of Term Assembly');
      expect(insert['eventtype'], 'SCHOOL_EVENT');
    });

    test('copyWith preserves unchanged fields', () {
      final e = CalendarEvent.fromMap(baseMap);
      final updated = e.copyWith(eventName: 'Updated Name');
      expect(updated.eventId, e.eventId);
      expect(updated.createdBy, e.createdBy);
      expect(updated.eventName, 'Updated Name');
      expect(updated.eventType, e.eventType);
    });

    test('copyWith changes only the specified field', () {
      final e = CalendarEvent.fromMap(baseMap);
      final updated = e.copyWith(eventType: CalendarEventType.exam);
      expect(updated.eventType, CalendarEventType.exam);
      expect(updated.eventName, e.eventName);
    });
  });
}
