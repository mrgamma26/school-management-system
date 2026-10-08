import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/communications/domain/models/notification_model.dart';

void main() {
  group('NotificationModel.fromJson', () {
    const baseJson = {
      'notificationid': 'notif-001',
      'guardianid': 'grd-001',
      'sentby': 'staff-001',
      'subject': 'Fee Reminder',
      'message': 'Please settle your outstanding fees.',
      'emailstatus': 'SENT',
      'readstatus': 'UNREAD',
      'sentat': '2024-03-10T09:00:00.000Z',
      'readat': null,
      'createdat': '2024-03-10T09:00:00.000Z',
    };

    test('parses all required fields', () {
      final n = NotificationModel.fromJson(baseJson);
      expect(n.notificationId, 'notif-001');
      expect(n.guardianId, 'grd-001');
      expect(n.sentBy, 'staff-001');
      expect(n.subject, 'Fee Reminder');
      expect(n.emailStatus, 'SENT');
      expect(n.readStatus, 'UNREAD');
    });

    test('isRead returns false when readstatus is UNREAD', () {
      final n = NotificationModel.fromJson(baseJson);
      expect(n.isRead, isFalse);
    });

    test('isRead returns true when readstatus is READ', () {
      final json = {...baseJson, 'readstatus': 'READ'};
      final n = NotificationModel.fromJson(json);
      expect(n.isRead, isTrue);
    });

    test('readAt is null when absent', () {
      final n = NotificationModel.fromJson(baseJson);
      expect(n.readAt, isNull);
    });

    test('readAt is parsed when present', () {
      final json = {
        ...baseJson,
        'readstatus': 'READ',
        'readat': '2024-03-11T14:30:00.000Z',
      };
      final n = NotificationModel.fromJson(json);
      expect(n.readAt, isNotNull);
      expect(n.readAt!.year, 2024);
    });

    test('resolves joined guardian name', () {
      final json = {
        ...baseJson,
        'guardian': {'firstname': 'Fatuma', 'lastname': 'Chigwe'},
      };
      final n = NotificationModel.fromJson(json);
      expect(n.guardianName, 'Fatuma Chigwe');
    });

    test('resolves joined sender name', () {
      final json = {
        ...baseJson,
        'staff': {'firstname': 'John', 'lastname': 'Banda'},
      };
      final n = NotificationModel.fromJson(json);
      expect(n.sentByName, 'John Banda');
    });

    test('joined names are null when not included in query', () {
      final n = NotificationModel.fromJson(baseJson);
      expect(n.guardianName, isNull);
      expect(n.sentByName, isNull);
    });
  });
}
