import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/academics/data/academic_repository.dart';
import 'package:school_management_app/features/academics/domain/models/academic_year.dart';
import 'package:school_management_app/features/academics/domain/models/class_model.dart';
import 'package:school_management_app/features/students/presentation/student_form_page.dart';

class RegistrationAcademics extends AcademicRepository {
  int classRequests = 0;

  @override
  Future<List<AcademicYear>> listAcademicYears() async => [
    AcademicYear(
      id: '2026-t1-f1',
      year: 2026,
      term: 'TERM_1',
      form: 'FORM_1',
      startDate: DateTime(2026),
      endDate: DateTime(2027),
    ),
    AcademicYear(
      id: '2026-t1-f2',
      year: 2026,
      term: 'TERM_1',
      form: 'FORM_2',
      startDate: DateTime(2026),
      endDate: DateTime(2027),
    ),
    AcademicYear(
      id: '2027-t2-f1',
      year: 2027,
      term: 'TERM_2',
      form: 'FORM_1',
      startDate: DateTime(2027),
      endDate: DateTime(2028),
    ),
  ];

  @override
  Future<List<ClassModel>> listClasses() async {
    classRequests++;
    return const [
      ClassModel(classId: 'class-1', className: 'Form 1A', form: 'FORM_1'),
      ClassModel(classId: 'class-2', className: 'Form 2A', form: 'FORM_2'),
    ];
  }
}

void main() {
  testWidgets(
    'period labels are explicit and classes are restricted to the same form',
    (tester) async {
      final repo = RegistrationAcademics();
      String? yearId;
      String? classId;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            registrationAcademicRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Form(
                    child: RegistrationClassAssignment(
                      academicYearId: yearId,
                      classId: classId,
                      onYearChanged: (value) => setState(() {
                        yearId = value;
                        classId = null;
                      }),
                      onClassChanged: (value) =>
                          setState(() => classId = value),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      DropdownButtonFormField<String> classField() =>
          tester.widget<DropdownButtonFormField<String>>(
            find.byWidgetPredicate(
              (w) =>
                  w is DropdownButtonFormField<String> &&
                  w.decoration.labelText == 'Class (optional)',
            ),
          );

      expect(classField().onChanged, isNull);
      expect(repo.classRequests, 0);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('2026/2027 · Term 1 · Form 1'), findsOneWidget);
      expect(find.text('2026/2027 · Term 1 · Form 2'), findsOneWidget);
      await tester.tap(find.text('2026/2027 · Term 1 · Form 1'));
      await tester.pumpAndSettle();

      expect(yearId, '2026-t1-f1');
      expect(classField().onChanged, isNotNull);
      expect(find.text('Showing Form 1 classes only'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      expect(find.text('Form 1A'), findsOneWidget);
      expect(find.text('Form 2A'), findsNothing);
      await tester.tap(find.text('Form 1A'));
      await tester.pumpAndSettle();
      expect(classId, 'class-1');

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2027/2028 · Term 2 · Form 1'));
      await tester.pumpAndSettle();
      expect(yearId, '2027-t2-f1');
      expect(classId, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign later').last);
      await tester.pumpAndSettle();
      expect(yearId, isNull);
      expect(classField().onChanged, isNull);
    },
  );
}
