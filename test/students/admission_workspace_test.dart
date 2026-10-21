import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_management_app/features/academics/data/academic_setup_repository.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/students/domain/admission_progress.dart';
import 'package:school_management_app/features/students/presentation/student_form_page.dart';
import 'registration_class_assignment_test.dart' show RegistrationAcademics;
import 'student_registration_flow_test.dart'
    show RegistrationAuth, RegistrationUsers;

class _FakeSetup extends AcademicSetupRepository {
  List<Map<String, dynamic>> rows;
  _FakeSetup(this.rows);
  @override
  Future<List<Map<String, dynamic>>> configuredSubjects() async => rows;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AdmissionProgress', () {
    AdmissionProgress progress({
      String first = '',
      String last = '',
      bool dob = false,
      int existing = 0,
      List<NewGuardianDraft> drafts = const [],
      bool classChosen = false,
    }) => AdmissionProgress.from(
      firstName: first,
      lastName: last,
      hasDateOfBirth: dob,
      existingGuardians: existing,
      newGuardianDrafts: drafts,
      classChosen: classChosen,
    );

    test('nothing typed: student stage is current and submit is blocked', () {
      final p = progress();
      expect(p.canSubmit, isFalse);
      expect(p.currentStage, AdmissionProgress.studentStage);
      expect(p.blockers, contains('Date of birth'));
      expect(p.completedStages, isEmpty);
    });

    test('a linked guardian satisfies the guardian requirement', () {
      final p = progress(first: 'A', last: 'B', dob: true, existing: 1);
      expect(p.canSubmit, isTrue);
      expect(p.currentStage, AdmissionProgress.classStage);
      expect(p.blockers, isEmpty);
      expect(
        p.completedStages,
        containsAll([
          AdmissionProgress.studentStage,
          AdmissionProgress.guardianStage,
          AdmissionProgress.reviewStage,
        ]),
      );
    });

    test('a half-filled new guardian blocks submit', () {
      final p = progress(
        first: 'A',
        last: 'B',
        dob: true,
        existing: 1,
        drafts: const [NewGuardianDraft(firstName: 'Only', touched: true)],
      );
      expect(p.guardianReady, isFalse);
      expect(p.canSubmit, isFalse);
      expect(p.currentStage, AdmissionProgress.guardianStage);
    });

    test('a complete new guardian counts and the class stays optional', () {
      final p = progress(
        first: 'A',
        last: 'B',
        dob: true,
        drafts: const [
          NewGuardianDraft(
            firstName: 'G',
            lastName: 'H',
            email: 'g@example.test',
            touched: true,
          ),
        ],
        classChosen: true,
      );
      expect(p.canSubmit, isTrue);
      expect(p.newGuardians, 1);
      expect(p.guardiansToLink, 1);
      expect(p.currentStage, AdmissionProgress.reviewStage);
    });
  });

  testWidgets(
    'workspace shows the five stages, a live summary and the class subjects',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => RegistrationAuth('ADMINISTRATOR')),
            registrationAcademicRepositoryProvider.overrideWithValue(
              RegistrationAcademics(),
            ),
            registrationUserRepositoryProvider.overrideWithValue(
              RegistrationUsers(),
            ),
            registrationSetupRepositoryProvider.overrideWithValue(
              _FakeSetup([
                {
                  'class_id': 'class-1',
                  'subject': {'subjectname': 'Biology'},
                },
                {
                  'class_id': 'class-1',
                  'subject': {'subjectname': 'Chichewa'},
                },
                {
                  'class_id': 'other-class',
                  'subject': {'subjectname': 'Physics'},
                },
              ]),
            ),
          ],
          child: const MaterialApp(home: StudentFormPage()),
        ),
      );
      await tester.pumpAndSettle();

      for (final title in [
        'Student identity',
        'Guardian and relationship',
        'Current class',
        'Guardian access',
        'Review and submit',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('One submission creates'), findsOneWidget);
      expect(find.textContaining('Still needed'), findsWidgets);
      // Exactly one submit button.
      expect(
        find.widgetWithText(FilledButton, 'Register Student'),
        findsOneWidget,
      );

      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(field('First Name').first, 'Sibling');
      await tester.enterText(field('Last Name').first, 'Student');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tap to select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Student record: Sibling Student'), findsOneWidget);

      // Pick a year and class; the preview lists only that class's subjects.
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText ==
                  'Academic year, term and form (optional)',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026/2027 · Term 1 · Form 1').last);
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

      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('Chichewa'), findsOneWidget);
      expect(find.text('Physics'), findsNothing);
      expect(find.textContaining('2 subjects generated'), findsWidgets);
      expect(find.textContaining('Enrolment in Form 1A'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
