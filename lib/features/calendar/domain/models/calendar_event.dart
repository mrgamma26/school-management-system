/// Domain model for a school calendar event.
class CalendarEvent {
  final String eventId;
  final String? classId;
  final String? className;
  final String createdBy;        // staffid
  final String createdByName;    // staff full name
  final String eventName;
  final CalendarEventType eventType;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;
  final String? academicYearId;
  final String? academicYearLabel;
  final DateTime createdAt;

  const CalendarEvent({
    required this.eventId,
    this.classId,
    this.className,
    required this.createdBy,
    required this.createdByName,
    required this.eventName,
    required this.eventType,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.allDay,
    this.academicYearId,
    this.academicYearLabel,
    required this.createdAt,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> m) {
    final classMap        = m['class']       as Map<String, dynamic>?;
    final staffMap        = m['staff']        as Map<String, dynamic>?;
    final yearMap         = m['academicyear'] as Map<String, dynamic>?;

    final staffFirst = staffMap?['firstname'] as String? ?? '';
    final staffLast  = staffMap?['lastname']  as String? ?? '';

    return CalendarEvent(
      eventId:          m['eventid']   as String,
      classId:          m['classid']   as String?,
      className:        classMap?['classname'] as String?,
      createdBy:        m['createdby'] as String,
      createdByName:    '$staffFirst $staffLast'.trim(),
      eventName:        m['eventname'] as String,
      eventType:        CalendarEventType.fromString(m['eventtype'] as String),
      description:      m['description'] as String?,
      startTime:        DateTime.parse(m['starttime'] as String).toLocal(),
      endTime:          DateTime.parse(m['endtime']   as String).toLocal(),
      allDay:           (m['allday'] as bool?) ?? false,
      academicYearId:   m['academicyearid'] as String?,
      academicYearLabel: yearMap != null
          ? '${yearMap['academicyear']} ${yearMap['term']}'
          : null,
      createdAt:        DateTime.parse(m['createdat'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        if (classId != null)        'classid':        classId,
        'createdby':                createdBy,
        'eventname':                eventName,
        'eventtype':                eventType.value,
        if (description != null)    'description':    description,
        'starttime':                startTime.toUtc().toIso8601String(),
        'endtime':                  endTime.toUtc().toIso8601String(),
        'allday':                   allDay,
        if (academicYearId != null) 'academicyearid': academicYearId,
      };

  CalendarEvent copyWith({
    String? eventName,
    CalendarEventType? eventType,
    String? description,
    String? classId,
    String? academicYearId,
    DateTime? startTime,
    DateTime? endTime,
    bool? allDay,
  }) =>
      CalendarEvent(
        eventId:          eventId,
        classId:          classId          ?? this.classId,
        className:        className,
        createdBy:        createdBy,
        createdByName:    createdByName,
        eventName:        eventName        ?? this.eventName,
        eventType:        eventType        ?? this.eventType,
        description:      description      ?? this.description,
        startTime:        startTime        ?? this.startTime,
        endTime:          endTime          ?? this.endTime,
        allDay:           allDay           ?? this.allDay,
        academicYearId:   academicYearId   ?? this.academicYearId,
        academicYearLabel: academicYearLabel,
        createdAt:        createdAt,
      );
}

// ── Enum ─────────────────────────────────────────────────────────────────────

enum CalendarEventType {
  publicHoliday('PUBLIC_HOLIDAY', 'Public Holiday'),
  exam         ('EXAM',           'Exam'),
  timetable    ('TIMETABLE',      'Timetable'),
  schoolEvent  ('SCHOOL_EVENT',   'School Event'),
  termDate     ('TERM_DATE',      'Term Date');

  final String value;
  final String label;
  const CalendarEventType(this.value, this.label);

  static CalendarEventType fromString(String v) =>
      CalendarEventType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => CalendarEventType.schoolEvent,
      );
}
