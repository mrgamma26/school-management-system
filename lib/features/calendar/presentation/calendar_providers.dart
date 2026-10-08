import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/calendar_repository.dart';
import '../domain/models/calendar_event.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(),
);

final calendarMonthProvider =
    FutureProvider.family<List<CalendarEvent>, ({int year, int month})>((
      ref,
      args,
    ) {
      return ref
          .watch(calendarRepositoryProvider)
          .listForMonth(year: args.year, month: args.month);
    });

final calendarClassesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(calendarRepositoryProvider).listClasses();
});

final calendarYearsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(calendarRepositoryProvider).listAcademicYears();
});
