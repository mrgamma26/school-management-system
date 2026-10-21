import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/academics/domain/class_setup_matrix.dart';

void main() {
  group('formFromClassName', () {
    test('reads the form level from the start of the name', () {
      expect(formFromClassName('Form 3C'), 'FORM_3');
      expect(formFromClassName('form 1'), 'FORM_1');
      expect(formFromClassName('  FORM2B'), 'FORM_2');
      expect(formFromClassName('Form 4 Science'), 'FORM_4');
    });

    test('returns null when the name does not start with Form 1 to 4', () {
      expect(formFromClassName('Grade 5'), isNull);
      expect(formFromClassName('Form 5A'), isNull);
      expect(formFromClassName('Form 12'), isNull);
      expect(formFromClassName('Science Form 2'), isNull);
      expect(formFromClassName(''), isNull);
    });
  });

  group('validateClassName', () {
    final existing = [
      {'classid': 'c1', 'classroomname': 'Form 1A', 'form': 'FORM_1'},
    ];

    test('needs a name that starts with Form 1 to Form 4', () {
      expect(validateClassName(name: '  ', existing: existing), isNotNull);
      expect(
        validateClassName(name: 'Grade 5', existing: existing),
        'Start the class name with Form 1, 2, 3 or 4, for example Form 2B.',
      );
      expect(validateClassName(name: 'Form 3C', existing: existing), isNull);
    });

    test('refuses a duplicate name but lets a class keep its own', () {
      expect(
        validateClassName(name: 'form 1a', existing: existing),
        'A class with this name already exists.',
      );
      expect(
        validateClassName(
          name: 'Form 1A',
          existing: existing,
          editingClassId: 'c1',
        ),
        isNull,
      );
    });

    test('refuses a very long name', () {
      expect(
        validateClassName(name: 'Form 1${'A' * 90}', existing: existing),
        isNotNull,
      );
    });
  });

  group('validateClassRename', () {
    final existing = [
      {'classid': 'c1', 'classroomname': 'Form 1A', 'form': 'FORM_1'},
      {'classid': 'c2', 'classroomname': 'Form 2A', 'form': 'FORM_2'},
    ];

    test('allows a new name inside the same form', () {
      expect(
        validateClassRename(
          name: 'Form 1B',
          currentForm: 'FORM_1',
          existing: existing,
          editingClassId: 'c1',
        ),
        isNull,
      );
    });

    test('lets a class keep its own name or change only its case', () {
      expect(
        validateClassRename(
          name: 'form 1a',
          currentForm: 'FORM_1',
          existing: existing,
          editingClassId: 'c1',
        ),
        isNull,
      );
    });

    test('refuses a name that moves the class to another form', () {
      expect(
        validateClassRename(
          name: 'Form 2B',
          currentForm: 'FORM_1',
          existing: existing,
          editingClassId: 'c1',
        ),
        'A rename cannot move the class to another form. Keep the name starting with Form 1.',
      );
    });

    test('refuses another class\'s name and names without a form', () {
      expect(
        validateClassRename(
          name: 'Form 2A',
          currentForm: 'FORM_2',
          existing: existing,
          editingClassId: 'c1',
        ),
        'A class with this name already exists.',
      );
      expect(
        validateClassRename(
          name: 'Grade 5',
          currentForm: 'FORM_1',
          existing: existing,
          editingClassId: 'c1',
        ),
        isNotNull,
      );
    });
  });

  test('a reassign reason is optional but bounded', () {
    expect(validateReassignReason(null), isNull);
    expect(validateReassignReason('  '), isNull);
    expect(validateReassignReason('Teacher on leave'), isNull);
    expect(validateReassignReason('x' * 201), isNotNull);
  });

  test('form level labels', () {
    expect(formLevelLabel('FORM_3'), 'Form 3');
    expect(formLevelLabel(null), '');
  });

  group('teachersForSubject', () {
    final teachers = [
      {'staffid': 't1', 'firstname': 'Peter', 'lastname': 'Mwale'},
      {'staffid': 't2', 'firstname': 'Alinafe', 'lastname': 'Chirwa'},
      {'staffid': 't3', 'firstname': 'Zione', 'lastname': 'Banda'},
    ];
    final marks = [
      {'staff_id': 't1', 'subject_id': 's1'},
      {'staff_id': 't2', 'subject_id': 's1'},
      {'staff_id': 't2', 'subject_id': 's2'},
    ];

    test('lists only teachers marked for the subject, by name', () {
      final biology = teachersForSubject(
        subjectId: 's1',
        teachers: teachers,
        staffSubjects: marks,
      );
      expect(biology.map((t) => t['staffid']), ['t2', 't1']);
      final chichewa = teachersForSubject(
        subjectId: 's2',
        teachers: teachers,
        staffSubjects: marks,
      );
      expect(chichewa.map((t) => t['staffid']), ['t2']);
    });

    test('a subject nobody is marked for has no candidates', () {
      expect(
        teachersForSubject(
          subjectId: 's9',
          teachers: teachers,
          staffSubjects: marks,
        ),
        isEmpty,
      );
    });

    test('the current teacher can be left out of a change list', () {
      final others = teachersForSubject(
        subjectId: 's1',
        teachers: teachers,
        staffSubjects: marks,
        excludeStaffId: 't2',
      );
      expect(others.map((t) => t['staffid']), ['t1']);
    });
  });

  group('ClassSetupMatrix', () {
    final matrix = ClassSetupMatrix.build(
      classes: [
        {'classid': 'c1', 'classroomname': 'Form 1A', 'form': 'FORM_1'},
        {'classid': 'c2', 'classroomname': 'Form 2A', 'form': 'FORM_2'},
      ],
      subjects: [
        {'subjectid': 's1', 'subjectname': 'Biology'},
        {'subjectid': 's2', 'subjectname': 'Chichewa'},
        {'subjectid': 's3', 'subjectname': 'Unused'},
      ],
      configured: [
        {'class_subject_id': 'cs1', 'class_id': 'c1', 'subject_id': 's1'},
        {'class_subject_id': 'cs2', 'class_id': 'c2', 'subject_id': 's1'},
        {'class_subject_id': 'cs3', 'class_id': 'c2', 'subject_id': 's2'},
      ],
      assignments: [
        {
          'class_subject_id': 'cs2',
          'staff_id': 't1',
          'staff': {
            'firstname': 'Peter',
            'middlename': null,
            'lastname': 'Mwale',
          },
        },
        {
          'class_subject_id': 'cs3',
          'staff_id': 't1',
          'staff': {
            'firstname': 'Peter',
            'middlename': null,
            'lastname': 'Mwale',
          },
        },
      ],
    );

    test('only offered subjects become rows', () {
      expect(matrix.subjects.map((s) => s['subjectname']), [
        'Biology',
        'Chichewa',
      ]);
    });

    test('cells carry the assigned teacher, or none', () {
      expect(matrix.cell('c1', 's1')!.isAssigned, isFalse);
      final filled = matrix.cell('c2', 's1')!;
      expect(filled.isAssigned, isTrue);
      expect(filled.teacherName, 'Peter Mwale');
      expect(filled.classSubjectId, 'cs2');
      expect(matrix.cell('c1', 's2'), isNull);
    });

    test('counts per class and overall', () {
      expect(matrix.assignedCount, 2);
      expect(matrix.openCount, 1);
      expect(matrix.offeredInClass('c2'), 2);
      expect(matrix.assignedInClass('c2'), 2);
      expect(matrix.assignedInClass('c1'), 0);
    });

    test('a teacher can hold several subjects', () {
      expect(matrix.loadOf('t1'), 2);
      expect(matrix.loadOf('t2'), 0);
    });

    test('subjects of one class are only the ones it offers', () {
      expect(matrix.subjectsOfClass('c1').map((s) => s['subjectname']), [
        'Biology',
      ]);
      expect(matrix.subjectsOfClass('c2').map((s) => s['subjectname']), [
        'Biology',
        'Chichewa',
      ]);
    });
  });
}
