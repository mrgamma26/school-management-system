# Teacher Assessment Workspace

## Purpose

Replace the academic-year-led teacher assessment page with a focused workflow
for creating assessments and recording grades for the teacher's active
class-and-subject assignments.

## Scope

This change applies to the teacher-facing **Assessments & Grades** page. The
existing **My Classes** page remains a read-only view of teaching assignments.

## Active assignment selection

The page resolves the current active academic year internally from the date.
It never displays an academic-year or term selector to a teacher. It loads only
the signed-in teacher's class-and-subject assignments in that active year.

If there is no active academic year or no teaching assignment, the page shows a
clear empty state explaining what the administrator needs to configure.

## Assessment workflow

The page contains a **Create Assessment** action. The dialog requires:

- Assessment name
- Assessment type: Quiz, Test, Exam, Assignment, Project, or Practical
- Maximum score
- A class from the teacher's active assignments
- A subject available for that selected class and teacher

Creating an assessment stores the existing `assessment` record linked to its
`classsubject` assignment, then opens grade entry for that assessment.

## Grade entry workflow

The grade page displays the assessment name, type, selected class, selected
subject, and maximum score. It contains a search field that filters the
students enrolled in the selected class.

Each student row shows the student's name, class, editable score field, and
grade status. Scores are validated as numeric and from zero through the
assessment maximum. Existing scores load for edits.

For large classes, the page retains the searchable scrollable list and adds
Previous Student and Next Student controls. Those controls move focus to the
prior or next visible student score field and report the current student
position, so keyboard and touch users can enter grades quickly without losing
their place.

The teacher submits all changed grades with **Save All Grades**. A saving state
prevents duplicate requests and the list refreshes after a successful save.

## Data, security, and errors

No schema migration is required. The feature uses the existing `classsubject`,
`assessment`, `studentclasshistory`, and `grade` tables.

The application continues to use teacher-scoped assignments and existing grade
permissions. Database RLS remains the final authority: a teacher can see only
students in classes assigned to that teacher's subject.

The page handles missing active-year configuration, no assignments, loading
states, failed assessment creation, invalid scores, and failed grade saves with
clear messages while retaining entered values where possible.

## Validation

Verify that a teacher sees no academic-year control, can create an assessment
only for their own class-and-subject assignments, can search and enter grades
for enrolled students, cannot enter a score above the maximum, can move through
students using Previous and Next controls, and can save and revisit grades.
