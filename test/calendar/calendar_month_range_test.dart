import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/calendar/data/calendar_repository.dart';
import 'package:school_management_app/features/calendar/domain/models/calendar_event.dart';

class CaptureRange extends CalendarRepository {
  DateTime? fromDate;
  DateTime? toDate;
  @override
  Future<List<CalendarEvent>> listForRange({
    required DateTime from,
    required DateTime to,
  }) async {
    fromDate = from;
    toDate = to;
    return [];
  }
}

void main() {
  test(
    'month query uses local boundaries and includes the complete last day',
    () async {
      final repo = CaptureRange();
      await repo.listForMonth(year: 2026, month: 12);
      expect(repo.fromDate, DateTime(2026, 12, 1));
      expect(repo.fromDate!.isUtc, isFalse);
      expect(
        repo.toDate,
        DateTime(2027, 1, 1).subtract(const Duration(microseconds: 1)),
      );
    },
  );
}
