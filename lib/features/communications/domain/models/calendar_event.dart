/// Calendar event row from the [calendarevent] table.
class CalendarEvent {
  final String eventId;
  final String? classId;
  final String createdBy;
  final String eventName;
  final String eventType;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;

  /// Optional joined data
  final String? className;
  final String? createdByName;

  const CalendarEvent({
    required this.eventId,
    this.classId,
    required this.createdBy,
    required this.eventName,
    required this.eventType,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    this.className,
    this.createdByName,
  });

  /// true when classId is null — this is a school-wide event
  bool get isSchoolWide => classId == null;

  factory CalendarEvent.fromJson(Map<String, dynamic> j) {
    final cls = j['class'] as Map<String, dynamic>?;
    final staff = j['staff'] as Map<String, dynamic>?;
    return CalendarEvent(
      eventId: j['eventid'] as String,
      classId: j['classid'] as String?,
      createdBy: j['createdby'] as String,
      eventName: j['eventname'] as String,
      eventType: j['eventtype'] as String,
      description: j['description'] as String?,
      startTime: DateTime.parse(j['starttime'] as String),
      endTime: DateTime.parse(j['endtime'] as String),
      createdAt: DateTime.parse(j['createdat'] as String),
      className: cls?['classname'] as String?,
      createdByName: staff != null
          ? '${staff['firstname']} ${staff['lastname']}'
          : null,
    );
  }

  @override
  String toString() => 'CalendarEvent($eventId, $eventName)';
}

/// Common event types — extend as needed.
const List<String> kEventTypes = [
  'EXAM',
  'HOLIDAY',
  'MEETING',
  'SPORTS',
  'TRIP',
  'CEREMONY',
  'OTHER',
];
