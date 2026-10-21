import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/academics/data/academic_repository.dart';
import 'package:school_management_app/features/academics/data/academic_setup_repository.dart';
import 'package:school_management_app/features/academics/presentation/pages/class_setup_page.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';

class _Role extends ActiveWorkspaceRoleNotifier {
  _Role(this.role);
  final String role;

  @override
  String build() => role;
}

class _FakeAcademic extends AcademicRepository {
  final created = <(String, String)>[];
  final renamed = <(String, String, String)>[];
  _FakeSetup? setup;

  @override
  Future<void> updateClass(
    String classId,
    String classroomName,
    String form,
  ) async {
    renamed.add((classId, classroomName, form));
    for (final row in setup!.classRows) {
      if (row['classid'] == classId) row['classroomname'] = classroomName;
    }
  }

  @override
  Future<void> createClass(String classroomName, String form) async {
    created.add((classroomName, form));
    setup!.classRows.add({
      'classid': 'new-class',
      'classroomname': classroomName,
      'form': form,
    });
  }
}

const _peter = {
  'staffid': 't1',
  'firstname': 'Peter',
  'middlename': null,
  'lastname': 'Mwale',
};
const _alinafe = {
  'staffid': 't2',
  'firstname': 'Alinafe',
  'middlename': null,
  'lastname': 'Chirwa',
};

class _FakeSetup extends AcademicSetupRepository {
  final classRows = <Map<String, dynamic>>[
    {'classid': 'c1', 'classroomname': 'Form 1A', 'form': 'FORM_1'},
  ];
  final configuredRows = <Map<String, dynamic>>[
    {
      'class_subject_id': 'cs1',
      'class_id': 'c1',
      'subject_id': 's1',
      'is_active': true,
    },
    {
      'class_subject_id': 'cs2',
      'class_id': 'c1',
      'subject_id': 's2',
      'is_active': true,
    },
  ];
  final assignmentRows = <Map<String, dynamic>>[
    {'class_subject_id': 'cs1', 'staff_id': 't1', 'staff': _peter},
  ];

  /// Peter teaches Biology only; Alinafe teaches Biology and Chichewa.
  final staffSubjectRows = <Map<String, dynamic>>[
    {'staff_id': 't1', 'subject_id': 's1'},
    {'staff_id': 't2', 'subject_id': 's1'},
    {'staff_id': 't2', 'subject_id': 's2'},
  ];

  final savedSubjects = <(String, Set<String>)>[];
  final assigned = <(String, Set<String>, String?)>[];
  final removed = <(String, String?)>[];
  final unlinked = <String>[];

  @override
  Future<List<Map<String, dynamic>>> classes() async =>
      List.of(classRows.map((r) => Map<String, dynamic>.of(r)));

  @override
  Future<List<Map<String, dynamic>>> subjects() async => [
    {'subjectid': 's1', 'subjectname': 'Biology'},
    {'subjectid': 's2', 'subjectname': 'Chichewa'},
    {'subjectid': 's3', 'subjectname': 'Physics'},
  ];

  @override
  Future<List<Map<String, dynamic>>> configuredSubjects() async =>
      List.of(configuredRows);

  @override
  Future<List<Map<String, dynamic>>> teachers() async => [_peter, _alinafe];

  @override
  Future<List<Map<String, dynamic>>> staffSubjects() async =>
      List.of(staffSubjectRows);

  @override
  Future<List<Map<String, dynamic>>> currentYearAssignments() async =>
      List.of(assignmentRows);

  @override
  Future<Map<String, dynamic>?> currentAcademicYear() async => {
    'academic_year_id': 'y1',
    'name': '2026',
  };

  @override
  Future<void> configureClassSubjects(
    String classId,
    Set<String> subjectIds,
  ) async {
    savedSubjects.add((classId, subjectIds));
    configuredRows
      ..removeWhere((r) => r['class_id'] == classId)
      ..addAll([
        for (final id in subjectIds)
          {
            'class_subject_id': 'cs-$classId-$id',
            'class_id': classId,
            'subject_id': id,
            'is_active': true,
          },
      ]);
  }

  @override
  Future<void> assignTeacher({
    required String staffId,
    required Set<String> classSubjectIds,
    String? replacementReason,
  }) async {
    assigned.add((staffId, classSubjectIds, replacementReason));
    for (final id in classSubjectIds) {
      assignmentRows
        ..removeWhere((r) => r['class_subject_id'] == id)
        ..add({
          'class_subject_id': id,
          'staff_id': staffId,
          'staff': staffId == 't1' ? _peter : _alinafe,
        });
    }
  }

  @override
  Future<void> removeTeacher({
    required String classSubjectId,
    String? reason,
  }) async {
    removed.add((classSubjectId, reason));
    assignmentRows.removeWhere((r) => r['class_subject_id'] == classSubjectId);
  }

  @override
  Future<void> unlinkClassSubject(String classSubjectId) async {
    unlinked.add(classSubjectId);
    assignmentRows.removeWhere((r) => r['class_subject_id'] == classSubjectId);
    configuredRows.removeWhere((r) => r['class_subject_id'] == classSubjectId);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeAcademic academic,
  required _FakeSetup setup,
  String role = 'ADMINISTRATOR',
}) async {
  tester.view.physicalSize = const Size(1500, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  academic.setup = setup;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeWorkspaceRoleProvider.overrideWith(() => _Role(role))],
      child: MaterialApp(
        home: Scaffold(
          body: ClassSetupPage(
            academicRepository: academic,
            setupRepository: setup,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the selected class with its subjects and teachers', (
    tester,
  ) async {
    await _pump(tester, academic: _FakeAcademic(), setup: _FakeSetup());

    expect(find.text('Form 1A subjects'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Chichewa'), findsOneWidget);
    expect(find.text('Peter Mwale'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('Needs teacher'), findsOneWidget);
    // Progress for the class in the list on the left.
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('the teacher list only offers teachers marked for the subject', (
    tester,
  ) async {
    final setup = _FakeSetup();
    await _pump(tester, academic: _FakeAcademic(), setup: setup);

    // Chichewa has no teacher yet; only Alinafe is marked as teaching it.
    await tester.tap(find.text('Select teacher'));
    await tester.pumpAndSettle();
    expect(find.text('Alinafe Chirwa (0 subjects)'), findsWidgets);
    expect(find.text('Peter Mwale (1 subject)'), findsNothing);

    await tester.tap(find.text('Alinafe Chirwa (0 subjects)').last);
    await tester.pumpAndSettle();

    expect(setup.assigned, hasLength(1));
    expect(setup.assigned.single.$1, 't2');
    expect(setup.assigned.single.$2, {'cs2'});
    expect(setup.assigned.single.$3, isNull);
    expect(find.textContaining('now teaches Chichewa'), findsOneWidget);
    expect(find.text('Needs teacher'), findsNothing);
  });

  testWidgets('Reassign can change the teacher and keeps the reason', (
    tester,
  ) async {
    final setup = _FakeSetup();
    await _pump(tester, academic: _FakeAcademic(), setup: setup);

    await tester.tap(find.text('Reassign'));
    await tester.pumpAndSettle();
    expect(find.text('Reassign Biology'), findsOneWidget);

    // Changing needs a teacher first.
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Select the new teacher.'), findsOneWidget);
    expect(setup.assigned, isEmpty);

    await tester.tap(find.text('Select new teacher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alinafe Chirwa').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Teacher on leave');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(setup.assigned, hasLength(1));
    expect(setup.assigned.single.$1, 't2');
    expect(setup.assigned.single.$2, {'cs1'});
    expect(setup.assigned.single.$3, 'Teacher on leave');
    expect(
      find.textContaining('is now taught by Alinafe Chirwa'),
      findsOneWidget,
    );
  });

  testWidgets('Reassign can remove the teacher and keep the subject linked', (
    tester,
  ) async {
    final setup = _FakeSetup();
    await _pump(tester, academic: _FakeAcademic(), setup: setup);

    await tester.tap(find.text('Reassign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove teacher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(setup.removed, [('cs1', null)]);
    expect(setup.unlinked, isEmpty);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Needs teacher'), findsNWidgets(2));
  });

  testWidgets('Reassign can unlink a subject from the class', (tester) async {
    final setup = _FakeSetup();
    await _pump(tester, academic: _FakeAcademic(), setup: setup);

    await tester.tap(find.text('Reassign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink subject from class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(setup.unlinked, ['cs1']);
    expect(find.text('Biology'), findsNothing);
    expect(find.text('Chichewa'), findsOneWidget);
  });

  testWidgets('New class takes a name only and follows it to the form', (
    tester,
  ) async {
    final academic = _FakeAcademic();
    await _pump(tester, academic: academic, setup: _FakeSetup());

    await tester.tap(find.text('New class'));
    await tester.pumpAndSettle();
    // No level picker: just the name field.
    expect(find.text('Form level'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Grade 5');
    await tester.tap(find.text('Create class'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Start the class name with Form 1, 2, 3 or 4, for example Form 2B.',
      ),
      findsOneWidget,
    );
    expect(academic.created, isEmpty);

    await tester.enterText(find.byType(TextField), 'Form 3C');
    await tester.pumpAndSettle();
    expect(find.text('Follows the Form 3 calendar and fees.'), findsOneWidget);
    await tester.tap(find.text('Create class'));
    await tester.pumpAndSettle();

    expect(academic.created, [('Form 3C', 'FORM_3')]);
    // The new class opens with nothing linked yet.
    expect(find.text('No subjects linked to Form 3C yet'), findsOneWidget);
  });

  testWidgets('Rename keeps the class in its form and keeps its subjects', (
    tester,
  ) async {
    final academic = _FakeAcademic();
    await _pump(tester, academic: academic, setup: _FakeSetup());

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Rename class'), findsOneWidget);
    // The dialog opens with the current name.
    expect(find.widgetWithText(TextField, 'Form 1A'), findsOneWidget);

    // Moving to another form is refused.
    await tester.enterText(find.byType(TextField), 'Form 2A');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'A rename cannot move the class to another form. Keep the name starting with Form 1.',
      ),
      findsOneWidget,
    );
    expect(academic.renamed, isEmpty);

    await tester.enterText(find.byType(TextField), 'Form 1B');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();

    expect(academic.renamed, hasLength(1));
    expect(academic.renamed.single.$1, 'c1');
    expect(academic.renamed.single.$2, 'Form 1B');
    expect(academic.renamed.single.$3, 'FORM_1');
    expect(find.text('Form 1B subjects'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Peter Mwale'), findsOneWidget);
  });

  testWidgets('Add subjects links only the ones not already in the class', (
    tester,
  ) async {
    final setup = _FakeSetup();
    await _pump(tester, academic: _FakeAcademic(), setup: setup);

    await tester.tap(find.text('Add subjects'));
    await tester.pumpAndSettle();
    expect(find.text('Add subjects to Form 1A'), findsOneWidget);
    // Biology and Chichewa are already linked; only Physics is offered.
    expect(find.byType(CheckboxListTile), findsOneWidget);

    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 subject'));
    await tester.pumpAndSettle();

    expect(setup.savedSubjects, hasLength(1));
    expect(setup.savedSubjects.single.$1, 'c1');
    expect(setup.savedSubjects.single.$2, {'s1', 's2', 's3'});
  });

  testWidgets('a Head Teacher sees the page read-only', (tester) async {
    await _pump(
      tester,
      academic: _FakeAcademic(),
      setup: _FakeSetup(),
      role: 'HEAD_TEACHER',
    );

    expect(find.text('Peter Mwale'), findsOneWidget);
    expect(find.text('Not assigned'), findsOneWidget);
    expect(find.text('New class'), findsNothing);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Add subjects'), findsNothing);
    expect(find.text('Reassign'), findsNothing);
    expect(find.text('Select teacher'), findsNothing);
  });
}
