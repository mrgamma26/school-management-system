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
    for (final year in [2026, 2027])
      AcademicYear(
        id: '$year',
        year: year,
        term: 'TERM_1',
        startDate: DateTime(year),
        endDate: DateTime(year + 1),
      ),
  ];
  @override
  Future<List<ClassModel>> listClasses() async {
    classRequests++;
    return [const ClassModel(classId: 'class-1', className: 'Form 1A')];
  }
}

void main() {
  testWidgets(
    'class is optional, disabled before a year, and cleared on year change',
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
                  return RegistrationClassAssignment(
                    academicYearId: yearId,
                    classId: classId,
                    onYearChanged: (value) => setState(() {
                      yearId = value;
                      classId = null;
                    }),
                    onClassChanged: (value) => setState(() => classId = value),
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
      expect(yearId, isNull);
      expect(classId, isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026/2027').last);
      await tester.pumpAndSettle();
      expect(classField().onChanged, isNotNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Form 1A').last);
      await tester.pumpAndSettle();
      expect(classId, 'class-1');
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2027/2028').last);
      await tester.pumpAndSettle();
      expect(yearId, '2027');
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
