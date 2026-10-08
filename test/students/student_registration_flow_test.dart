import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_management_app/core/services/audit_service.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/students/data/student_repository.dart';
import 'package:school_management_app/features/students/presentation/student_form_page.dart';
import 'package:school_management_app/features/users/data/repositories/user_repository.dart';
import 'package:school_management_app/features/users/domain/models/guardian.dart';
import 'registration_class_assignment_test.dart' show RegistrationAcademics;

class RegistrationAuth extends AuthNotifier {
  RegistrationAuth(this.role);
  final String role;
  @override
  AuthState build() => AuthState(
    user: AppUser(
      userId: 'admin',
      username: 'Admin',
      roleId: 'admin-role',
      roleName: role,
      mustChangePassword: false,
      isActive: true,
    ),
  );
}

class RegistrationStudents extends StudentRepository {
  int creations = 0;
  int placements = 0;
  DateTime? enrolled;
  bool failLink = false;
  final linkedGuardians = <String>[];
  @override
  Future<String> createStudent(Map<String, dynamic> data) async {
    expect(data['enrollmentstatus'], 'enrolled');
    creations++;
    return 'student';
  }

  @override
  Future<void> assignClass({
    required String studentId,
    required String classId,
    required String academicYearId,
    required DateTime enrollmentDate,
  }) async {
    expect(classId, 'class-1');
    expect(academicYearId, '2026');
    placements++;
    enrolled = enrollmentDate;
  }

  @override
  Future<void> enrolInClassSubjects({
    required String studentId,
    required String classId,
    required String academicYearId,
  }) async {}

  @override
  Future<void> linkGuardian({
    required String studentId,
    required String guardianId,
    required String relationship,
  }) async {
    if (failLink) {
      failLink = false;
      throw Exception('Temporary link failure');
    }
    linkedGuardians.add(guardianId);
  }
}

class RegistrationUsers extends UserRepository {
  int creations = 0;
  @override
  Future<List<Map<String, dynamic>>> listRoles() async => [
    {'rolename': 'GUARDIAN', 'roleid': 'guardian-role'},
  ];
  @override
  Future<String> createUser(Map<String, dynamic> payload) async {
    expect(payload['userType'], 'GUARDIAN');
    expect(payload['password'], isNotEmpty);
    creations++;
    return 'guardian-user';
  }

  @override
  Future<Map<String, dynamic>> getGuardianByUserId(String userId) async => {
    'guardianid': 'guardian',
  };

  @override
  Future<List<Guardian>> listGuardians({int offset = 0}) async => const [
    Guardian(
      guardianId: 'existing-guardian',
      firstName: 'Existing',
      lastName: 'Parent',
      gender: 'FEMALE',
      email: 'parent@example.test',
    ),
  ];
}

class RegistrationAudit extends AuditService {
  final actions = <String>[];
  @override
  Future<void> log({
    required String userId,
    required String action,
    required String tableName,
    String? recordId,
    Map<String, dynamic>? previousValue,
    Map<String, dynamic>? newValue,
    String? reason,
    String? actorRole,
  }) async {
    actions.add(action);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('unfinished student registration restores a local draft', (
    tester,
  ) async {
    final scope = ProviderScope(
      overrides: [
        authProvider.overrideWith(() => RegistrationAuth('SUPER_USER')),
        registrationAcademicRepositoryProvider.overrideWithValue(
          RegistrationAcademics(),
        ),
        registrationUserRepositoryProvider.overrideWithValue(
          RegistrationUsers(),
        ),
      ],
      child: const MaterialApp(home: StudentFormPage()),
    );
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    Finder firstName = find
        .byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'First Name',
        )
        .first;
    await tester.enterText(firstName, 'Saved Student');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    firstName = find
        .byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'First Name',
        )
        .first;
    expect(
      tester.widget<TextField>(firstName).controller?.text,
      'Saved Student',
    );
  });

  testWidgets(
    'registration can link an existing guardian without a new account',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final students = RegistrationStudents();
      final users = RegistrationUsers();
      final audit = RegistrationAudit();
      final router = GoRouter(
        initialLocation: '/students/new',
        routes: [
          GoRoute(
            path: '/students/new',
            builder: (_, _) => const StudentFormPage(),
          ),
          GoRoute(
            path: '/admin/home',
            builder: (_, _) => const Scaffold(body: Text('Dashboard')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => RegistrationAuth('SUPER_USER')),
            registrationAcademicRepositoryProvider.overrideWithValue(
              RegistrationAcademics(),
            ),
            registrationStudentRepositoryProvider.overrideWithValue(students),
            registrationUserRepositoryProvider.overrideWithValue(users),
            registrationAuditProvider.overrideWithValue(audit),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(field('First Name').first, 'Sibling');
      await tester.enterText(field('Last Name').first, 'Student');
      await tester.tap(find.text('Tap to select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link Existing Parent or Guardian'));
      await tester.pumpAndSettle();
      expect(find.text('Existing Parent'), findsOneWidget);
      await tester.tap(find.text('Existing Parent'));
      await tester.pumpAndSettle();

      final submit = find.widgetWithText(FilledButton, 'Register Student');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(students.creations, 1);
      expect(students.linkedGuardians, ['existing-guardian']);
      expect(users.creations, 0);
      expect(audit.actions, contains('EXISTING_GUARDIAN_LINKED_TO_STUDENT'));
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final assign in [false, true]) {
    testWidgets(
      'registration ${assign ? 'with placement resumes after a link failure' : 'can skip class assignment'}',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final students = RegistrationStudents()..failLink = assign;
        final users = RegistrationUsers();
        final audit = RegistrationAudit();
        final home = assign ? '/administrator/home' : '/admin/home';
        final router = GoRouter(
          initialLocation: assign ? home : '/students/new',
          routes: [
            ShellRoute(
              builder: (context, state, child) => child,
              routes: [
                GoRoute(
                  path: home,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Dashboard')),
                ),
                GoRoute(
                  path: '/students/new',
                  builder: (context, state) => const StudentFormPage(),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => RegistrationAuth(assign ? 'ADMINISTRATOR' : 'SUPER_USER'),
              ),
              registrationAcademicRepositoryProvider.overrideWithValue(
                RegistrationAcademics(),
              ),
              registrationStudentRepositoryProvider.overrideWithValue(students),
              registrationUserRepositoryProvider.overrideWithValue(users),
              registrationAuditProvider.overrideWithValue(audit),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (assign) {
          router.push<void>('/students/new');
          await tester.pumpAndSettle();
        }
        Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await tester.enterText(field('First Name').first, 'Student');
        await tester.enterText(field('Last Name').first, 'Example');
        await tester.tap(find.text('Tap to select'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        if (assign) {
          await tester.tap(
            find.byWidgetPredicate(
              (w) =>
                  w is DropdownButtonFormField<String> &&
                  w.decoration.labelText == 'Academic Year (optional)',
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('2026/2027').last);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate(
              (w) =>
                  w is DropdownButtonFormField<String> &&
                  w.decoration.labelText == 'Class (optional)',
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Form 1A').last);
          await tester.pumpAndSettle();
        }
        await tester.enterText(field('First Name').last, 'Guardian');
        await tester.enterText(field('Last Name').last, 'Example');
        await tester.enterText(field('Email address'), 'guardian@example.test');
        final submit = find.widgetWithText(FilledButton, 'Register Student');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        if (assign) {
          expect(find.textContaining('partially saved'), findsOneWidget);
          await tester.ensureVisible(submit);
          await tester.tap(submit);
          await tester.pumpAndSettle();
        }
        expect(students.creations, 1);
        expect(users.creations, 1);
        expect(students.placements, assign ? 1 : 0);
        if (assign) {
          expect(students.enrolled, DateUtils.dateOnly(DateTime.now()));
        }
        expect(audit.actions, contains('STUDENT_CREATED'));
        expect(audit.actions, contains('GUARDIAN_CREATED_FOR_STUDENT'));
        if (assign) expect(audit.actions, contains('STUDENT_CLASS_ASSIGNED'));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('guardian@example.test'), findsWidgets);
        await tester.tap(find.widgetWithText(FilledButton, 'Done'));
        await tester.pumpAndSettle();
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.byType(StudentFormPage), findsNothing);
        expect(router.routeInformationProvider.value.uri.path, home);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
