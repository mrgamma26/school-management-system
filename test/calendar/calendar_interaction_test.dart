import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/calendar/data/calendar_repository.dart';
import 'package:school_management_app/features/calendar/domain/models/calendar_event.dart';
import 'package:school_management_app/features/calendar/presentation/calendar_providers.dart';
import 'package:school_management_app/features/calendar/presentation/pages/calendar_page.dart';
import 'package:school_management_app/features/calendar/presentation/pages/calendar_event_form_page.dart';

class SignedIn extends AuthNotifier {
  SignedIn(this.role);
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

class FakeCalendar extends CalendarRepository {
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

  Future<void> open(WidgetTester tester, String role, FakeCalendar repo) async {
    tester.view.resetPhysicalSize();
    // Below calendarSidePanelBreakpoint (1100): the day-dialog layout.
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => SignedIn(role)),
          calendarRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final role in ['GUARDIAN', 'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT']) {
    testWidgets('$role can long-press details but cannot create', (
      tester,
    ) async {
      await open(tester, role, FakeCalendar());
      expect(find.text('Add Event'), findsNothing);
      await tester.tap(dayCell(15));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventFormPage), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Full meeting details for all families.'), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      await tester.longPress(dayCell(15));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Full meeting details for all families.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final role in ['SUPER_USER', 'ADMINISTRATOR']) {
    testWidgets('$role opens a day popup and saves without a staff profile', (
      tester,
    ) async {
      final repo = FakeCalendar();
      await open(tester, role, repo);
      await tester.tap(dayCell(15));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Event'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventFormPage), findsOneWidget);
      expect(find.textContaining('staff profile'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'New school event',
      );
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
      expect(repo.saved.single.createdByUser, 'admin-user');
      expect(repo.saved.single.createdBy, isEmpty);
      expect(repo.saved.single.startTime.day, 15);
      expect(
        repo.saved.single.endTime.isAfter(repo.saved.single.startTime),
        isTrue,
      );
      expect(find.byType(CalendarEventFormPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('admin can save the same event on nonconsecutive dates', (
    tester,
  ) async {
    final repo = FakeCalendar();
    await open(tester, 'SUPER_USER', repo);
    await tester.tap(dayCell(15));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Parent meetings');
    final formScroll = find
        .descendant(
          of: find.byType(CalendarEventFormPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Add date'),
      250,
      scrollable: formScroll,
    );
    await tester.tap(find.text('Add date'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('18'),
      ),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Create Event');
    await tester.scrollUntilVisible(save, 250, scrollable: formScroll);
    await tester.enterText(
      find.byType(TextFormField).last,
      'Bring the report card.',
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.saved.map((e) => e.startTime.day).toSet(), {15, 18});
    expect(
      repo.saved.every((e) => e.description == 'Bring the report card.'),
      isTrue,
    );
    expect(
      repo.saved.every((e) => e.startTime.hour == 9 && e.endTime.hour == 10),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
