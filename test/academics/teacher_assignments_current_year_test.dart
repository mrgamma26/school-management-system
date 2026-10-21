import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/academics/data/academic_setup_repository.dart';
import 'package:school_management_app/features/academics/presentation/pages/teacher_assignments_page.dart';

class _FakeSetup extends AcademicSetupRepository {
  _FakeSetup(this.year, {this.rows = const []});

  final Map<String, dynamic>? year;
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> assignments() async => rows;

  @override
  Future<Map<String, dynamic>?> currentAcademicYear() async => year;
}

Future<void> _pump(WidgetTester tester, _FakeSetup repository) async {
  tester.view.physicalSize = const Size(1400, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [academicSetupRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: TeacherAssignmentsPage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the active assignments with the current year', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeSetup(
        {'academic_year_id': 'y1', 'name': '2027/2028'},
        rows: [
          {
            'staff': {'firstname': 'Mary', 'lastname': 'Banda'},
            'class_subject': {
              'class': {'classroomname': 'Form 1A', 'form': 'FORM_1'},
              'subject': {'subjectname': 'English'},
            },
          },
        ],
      ),
    );

    expect(find.text('Classes You Teach'), findsOneWidget);
    expect(find.textContaining('2027/2028'), findsOneWidget);
    expect(find.text('Form 1A'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Mary Banda'), findsOneWidget);
  });

  testWidgets('is read-only: assigning happens in Class Setup', (tester) async {
    await _pump(tester, _FakeSetup(null));

    expect(find.text('No active teacher assignments yet'), findsOneWidget);
    expect(find.textContaining('Class Setup'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
