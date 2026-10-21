import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/auth/school_role_access.dart';
import 'package:school_management_app/core/navigation/role_menus.dart';
import 'package:school_management_app/core/router.dart';
import 'package:school_management_app/features/assessments/data/mark_workspace_repository.dart';
import 'package:school_management_app/features/assessments/data/review_workspace_repository.dart';

Map<String, dynamic> assignmentRow({
  String? periodForm = 'FORM_1',
  String? classForm = 'FORM_1',
}) => {
  'classsubjectid': 'cs-1',
  'class': {'classroomname': 'Form 1A', 'form': classForm},
  'subject': {'subjectname': 'Biology'},
  'academicyear': {
    'academicyearid': 'ay-1',
    'academicyear': 2026,
    'term': 'TERM_2',
    'form': periodForm,
    'startdate': '2026-09-01',
    'enddate': '2026-12-15',
  },
};

Iterable<String> routesOf(List<MenuNode> nodes) sync* {
  for (final node in nodes) {
    if (node.route != null) yield node.route!;
    yield* routesOf(node.children);
  }
}

void main() {
  group('TeacherAssignment.fromRow', () {
    test('keeps an assignment whose class and period forms match', () {
      final a = TeacherAssignment.fromRow(assignmentRow())!;
      expect(a.classSubjectId, 'cs-1');
      expect(a.label, 'Biology · Form 1A');
      expect(a.periodLabel, '2026/2027 • TERM 2');
      expect(a.isCurrent(DateTime(2026, 10, 17)), isTrue);
      expect(a.isCurrent(DateTime(2026, 12, 16)), isFalse);
      expect(a.isCurrent(DateTime(2026, 9, 1)), isTrue);
    });

    test('drops assignments with a different or missing form', () {
      expect(
        TeacherAssignment.fromRow(assignmentRow(periodForm: 'FORM_2')),
        isNull,
      );
      expect(
        TeacherAssignment.fromRow(assignmentRow(periodForm: null)),
        isNull,
      );
      expect(TeacherAssignment.fromRow({'classsubjectid': 'x'}), isNull);
    });
  });

  test('SavedGrade reads status flags and the author', () {
    final g = SavedGrade.fromJson({
      'gradeid': 'g1',
      'studentid': 's1',
      'score': 72.5,
      'gradestatus': 'PRESENT',
      'submissionstatus': 'SUBMITTED',
      'published_at': null,
      'createdat': '2026-10-12T08:00:00Z',
      'updatedat': '2026-10-16T09:30:00Z',
      'enteredby': 'st1',
      'author': {'firstname': 'Yamikani', 'lastname': 'Nkosi'},
    });
    expect(g.score, 72.5);
    expect(g.submitted, isTrue);
    expect(g.published, isFalse);
    expect(g.enteredByName, 'Yamikani Nkosi');
  });

  group('review queue and detail', () {
    final item = ReviewQueueItem.fromJson({
      'assessmentid': 'a1',
      'assessmentname': 'Term 2 Examination',
      'assessmenttype': 'EXAM',
      'maxscore': 100,
      'classsubject': {
        'classsubjectid': 'cs-1',
        'class': {'classroomname': 'Form 3A'},
        'subject': {'subjectname': 'Biology'},
        'staff': {'firstname': 'Yamikani', 'lastname': 'Nkosi'},
        'academicyear': {'academicyear': 2026, 'term': 'TERM_2'},
      },
      'grade': [
        {'gradeid': 'g1', 'updatedat': '2026-10-15T10:00:00Z'},
        {'gradeid': 'g2', 'updatedat': '2026-10-16T10:00:00Z'},
      ],
    });

    test('queue item reads names, period and the awaiting count', () {
      expect(item.title, 'Biology · Form 3A');
      expect(item.teacherName, 'Yamikani Nkosi');
      expect(item.periodLabel, '2026/2027 • TERM 2');
      expect(item.awaitingGrades, 2);
      expect(item.maxScore, 100);
      expect(item.lastSubmittedAt!.toUtc().day, 16);
    });

    SavedGrade grade(String student, double? score, String status) =>
        SavedGrade(
          gradeId: 'g-$student',
          studentId: student,
          score: score,
          status: status,
          submitted: true,
          enteredByName: 'Yamikani Nkosi',
        );

    const roster = [
      RosterStudent(studentId: 's1', firstName: 'Ann', lastName: 'Banda'),
      RosterStudent(studentId: 's2', firstName: 'Ben', lastName: 'Phiri'),
      RosterStudent(studentId: 's3', firstName: 'Cat', lastName: 'Moyo'),
      RosterStudent(studentId: 's4', firstName: 'Dan', lastName: 'Zimba'),
      RosterStudent(studentId: 's5', firstName: 'Eve', lastName: 'Kalua'),
    ];

    test('students with no grade row are missing; absent is accounted for', () {
      final detail = ReviewDetail(
        item: item,
        roster: roster,
        grades: [
          grade('s1', 80, 'PRESENT'),
          grade('s2', 40, 'PRESENT'),
          grade('s3', null, 'ABSENT'),
          grade('s4', null, 'MISSING'),
          // s5 has no row at all.
        ],
        pendingCorrections: 1,
      );
      final stats = detail.stats;
      expect(stats.total, 5);
      expect(stats.valid, 2);
      expect(stats.absent, 1);
      expect(stats.missing, 2);
      expect(stats.ready, isFalse);
      expect(stats.averagePercent, 60);
      expect(detail.missingNames, ['Dan Zimba', 'Eve Kalua']);
      expect(detail.validScores, [80, 40]);
      expect(detail.authors, ['Yamikani Nkosi']);
      expect(detail.awaitingCount, 4);
    });

    test('a stored score above the maximum is reported as invalid', () {
      final detail = ReviewDetail(
        item: item,
        roster: roster.take(1).toList(),
        grades: [grade('s1', 120, 'PRESENT')],
        pendingCorrections: 0,
      );
      expect(detail.invalidNames, ['Ann Banda']);
      expect(detail.stats.ready, isFalse);
    });

    test('a complete sheet is ready to publish', () {
      final detail = ReviewDetail(
        item: item,
        roster: roster.take(2).toList(),
        grades: [grade('s1', 55, 'PRESENT'), grade('s2', 61, 'PRESENT')],
        pendingCorrections: 0,
      );
      expect(detail.stats.ready, isTrue);
      expect(detail.missingNames, isEmpty);
    });
  });

  group('/results/review access', () {
    const roles = [
      'SUPER_USER',
      'ADMINISTRATOR',
      'HEAD_TEACHER',
      'TEACHER',
      'ACCOUNTANT',
      'GUARDIAN',
    ];

    test('only the roles that can publish may review', () {
      for (final role in roles) {
        final allowed = ['SUPER_USER', 'HEAD_TEACHER'].contains(role);
        expect(canReviewSubmittedResults(role), allowed, reason: role);
        expect(
          isRouteAllowedForRole(role, '/results/review'),
          allowed,
          reason: role,
        );
      }
      expect(canReviewSubmittedResults('SYSTEM_ADMIN'), isTrue);
    });

    test('the menu entry exists exactly for those roles', () {
      for (final role in roles) {
        expect(
          routesOf(roleMenus[role]!).contains('/results/review'),
          ['SUPER_USER', 'HEAD_TEACHER'].contains(role),
          reason: role,
        );
      }
    });

    test('the assessments deep link stays teacher-only', () {
      for (final role in roles) {
        expect(
          isRouteAllowedForRole(role, '/assessments/abc/grades'),
          role == 'TEACHER',
          reason: role,
        );
      }
    });
  });
}
