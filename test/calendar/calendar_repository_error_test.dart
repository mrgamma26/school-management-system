import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/errors/app_exception.dart';
import 'package:school_management_app/features/calendar/data/calendar_repository.dart';

void main() {
  group('mapCalendarException', () {
    test('explains when the calendar RPC is missing', () {
      final error = mapCalendarException(
        Exception(
          'PGRST202 Could not find the function public.create_calendar_events '
          'in the schema cache',
        ),
      );

      expect(error, isA<ServerException>());
      expect(
        error.message,
        'Calendar setup is out of date. Apply the latest database migration '
        'and try again.',
      );
    });

    test('explains when the authenticated author column is missing', () {
      final error = mapCalendarException(
        Exception('42703 column "createdbyuser" does not exist'),
      );

      expect(error, isA<ServerException>());
      expect(error.message, contains('latest database migration'));
    });

    test('keeps permission errors user friendly', () {
      final error = mapCalendarException(
        Exception('42501 permission denied for table calendarevent'),
      );

      expect(error, isA<ForbiddenException>());
      expect(
        error.message,
        'You do not have permission to perform this action.',
      );
    });
  });
}
