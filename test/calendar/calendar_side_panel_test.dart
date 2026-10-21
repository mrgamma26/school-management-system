import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/calendar/data/calendar_repository.dart';
import 'package:school_management_app/features/calendar/domain/models/calendar_event.dart';
import 'package:school_management_app/features/calendar/presentation/calendar_providers.dart';
import 'package:school_management_app/features/calendar/presentation/pages/calendar_event_form_page.dart';
import 'package:school_management_app/features/calendar/presentation/pages/calendar_page.dart';

class _SignedIn extends AuthNotifier {
  _SignedIn(this.role);
  final String role;
  @override
  AuthState build() => AuthState(
    user: AppUser(
      userId: 'admin-user',
      username: 'Admin',
      roleId: 'role',
      roleName: role,
      mustChangePassword: false,
      isActive: true,
    ),
  );
}

class _FakeCalendar extends CalendarRepository {
  List<CalendarEvent> saved = [];
  @override
  Future<List<Map<String, dynamic>>> listClasses() async => [];
  @override
  Future<List<Map<String, dynamic>>> listAcademicYears() async => [];
  @override
  Future<List<CalendarEvent>> listForMonth({
    required int year,
    required int month,
  }) async => [
    CalendarEvent(
      eventId: 'event',
      createdBy: '',
      createdByUser: 'admin-user',
      createdByName: 'Admin',
      eventName: 'School meeting',
      eventType: CalendarEventType.schoolEvent,
      description: 'Full meeting details for all families.',
      startTime: DateTime(year, month, 15, 9),
      endTime: DateTime(year, month, 15, 10),
      allDay: false,
      createdAt: DateTime(year, month, 1),
    ),
  ];
  @override
  Future<void> createMany({
    required List<CalendarEvent> events,
    required String actorUserId,
    required String actorRole,
  }) async {
    saved = events;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Finder dayCell(int day) {
    final now = DateTime.now();
    return find.byKey(ValueKey('calendar-day-${now.year}-${now.month}-$day'));
  }

  Future<void> open(
    WidgetTester tester,
    String role,
    _FakeCalendar repo, {
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _SignedIn(role)),
          calendarRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wide: an administrator edits beside the grid, no dialog', (
    tester,
  ) async {
    final repo = _FakeCalendar();
    await open(tester, 'ADMINISTRATOR', repo);

    expect(find.text('Select a date'), findsOneWidget);
    expect(find.byType(CalendarEventFormPage), findsNothing);

    await tester.tap(dayCell(15));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('calendar-side-panel')), findsOneWidget);
    expect(find.byType(CalendarEventFormPage), findsOneWidget);
    expect(find.text('School meeting'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, 'Science fair');
    final save = find.widgetWithText(FilledButton, 'Create Event');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find
          .descendant(
            of: find.byType(CalendarEventFormPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.eventName, 'Science fair');
    expect(repo.saved.single.startTime.day, 15);
    // The panel stays open on the same date, ready for the next event.
    expect(find.byKey(const ValueKey('calendar-side-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide: other roles still get the read-only day dialog', (
    tester,
  ) async {
    await open(tester, 'TEACHER', _FakeCalendar());
    await tester.tap(dayCell(15));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-side-panel')), findsNothing);
    expect(find.byType(CalendarEventFormPage), findsNothing);
  });

  testWidgets('narrow: administrators keep the dialog flow', (tester) async {
    await open(tester, 'ADMINISTRATOR', _FakeCalendar(), width: 1000);
    await tester.tap(dayCell(15));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-side-panel')), findsNothing);
  });
}
