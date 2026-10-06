# Teacher Dashboard Add Assessment Shortcut

## Purpose

Give teachers a clear dashboard action for starting an assessment while
preserving the existing assessment and grade-entry workflow.

## Scope

Add an **Add Assessment** tile to the teacher dashboard's Assessments & Grades
section. Selecting it opens the existing `/assessments` workspace.

The existing **Assessments & Grades** tile remains available as the general
entry point for reviewing assessments and grades.

## Workflow

1. The teacher selects **Add Assessment** from the dashboard.
2. The application opens the existing teacher-scoped Assessments & Grades
   workspace.
3. The teacher selects one of their active class-and-subject assignments.
4. The teacher uses the existing **Add Assessment** form to provide an
   assessment name, type, and maximum score.
5. The existing grade-entry page is used to enter grades for enrolled students
   by name and to save those grades.

## Architecture and data

No new route, repository, database table, assessment form, or grade-entry
logic is introduced. The dashboard tile reuses `/assessments`, whose existing
active-year resolution, teacher assignment filtering, permissions, RLS-backed
access, assessment creation, and grade-entry flow remain authoritative.

## Errors and validation

The shortcut inherits the workspace's existing handling for missing active
academic years, absent teaching assignments, assessment validation, failed
creation, invalid scores, and failed grade saves. The dashboard itself does
not create or validate assessment data.

## Validation

Verify that the teacher dashboard shows the new Add Assessment tile; tapping
it opens `/assessments`; a teacher can choose only an assigned class/subject;
the existing assessment form accepts its supported types; and grade entry
continues to list students by name and save grades through the existing page.
