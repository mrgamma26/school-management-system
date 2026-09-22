/// Notification row from the [notification] table.
class NotificationModel {
  final String notificationId;
  final String guardianId;
  final String sentBy;
  final String subject;
  final String message;
  final String emailStatus;
  final String readStatus;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime createdAt;

  /// Optional joined data
  final String? guardianName;
  final String? sentByName;

  const NotificationModel({
    required this.notificationId,
    required this.guardianId,
    required this.sentBy,
    required this.subject,
    required this.message,
    required this.emailStatus,
    required this.readStatus,
    this.sentAt,
    this.readAt,
    required this.createdAt,
    this.guardianName,
    this.sentByName,
  });

  bool get isRead => readStatus == 'READ';

  factory NotificationModel.fromJson(Map<String, dynamic> j) {
    final guardian = j['guardian'] as Map<String, dynamic>?;
    final staff = j['staff'] as Map<String, dynamic>?;
    return NotificationModel(
      notificationId: j['notificationid'] as String,
      guardianId: j['guardianid'] as String,
      sentBy: j['sentby'] as String,
      subject: j['subject'] as String,
      message: j['message'] as String,
      emailStatus: j['emailstatus'].toString(),
      readStatus: j['readstatus'].toString(),
      sentAt: j['sentat'] != null
          ? DateTime.parse(j['sentat'] as String)
          : null,
      readAt: j['readat'] != null
          ? DateTime.parse(j['readat'] as String)
          : null,
      createdAt: DateTime.parse(j['createdat'] as String),
      guardianName: guardian != null
          ? '${guardian['firstname']} ${guardian['lastname']}'
          : null,
      sentByName: staff != null
          ? '${staff['firstname']} ${staff['lastname']}'
          : null,
    );
  }

  @override
  String toString() => 'NotificationModel($notificationId, $subject)';
}
