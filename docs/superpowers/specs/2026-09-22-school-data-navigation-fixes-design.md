# School Data and Navigation Fixes

## Goal

Repair student and academic-year creation, make reports load real records, provide a collapsible side menu throughout the authenticated app, and show teachers the students in classes they teach.

## Behavior

- Student enrollment statuses sent to Supabase use the enum values defined by the schema: `ENROLLED`, `GRADUATED`, and `WITHDRAWN`.
- Academic-year reads and writes use the actual `term` column and the existing authenticated administrator RLS policy.
- The teacher Students view selects the current academic year, then lists classes represented by that teacher's `classsubject` assignments for the year, then lists students with an active `studentclasshistory` placement in the selected class and year.
- Reports select an academic year using the actual schema fields and load finance, enrolment, and performance data with explicit loading, empty, and error states.
- Authenticated pages render through the shared `AppShell`. Desktop keeps a collapsible sidebar; narrow layouts expose the same navigation through a drawer.

## Architecture

Keep the existing Riverpod providers, repositories, `AppShell`, and Supabase schema. Add repository methods for teacher assignments and class-filtered students rather than duplicating joins in page widgets. Use the existing `classsubject` relationship as the source of teacher-to-class ownership; do not add a redundant teacher column to `class`.

The existing migrations are append-only. Add a corrective migration for any RLS policy changes so deployed databases receive the fix without rewriting history.

## Error Handling

Supabase errors remain visible in page-level error states. Empty academic-year, class, and report results show an intentional empty state instead of an indefinite loader. Query field names must match the deployed schema (`term`, `classname`/`classroomname` as appropriate to the live schema).

## Validation

- Run focused Dart formatting and analyzer checks on touched Dart files.
- Run the relevant widget/repository tests where available.
- Verify the migration parses and inspect the final diff.
- Manually verify: create a student, create an academic year as an administrator, select a current year/class as a teacher, and open each report tab.
