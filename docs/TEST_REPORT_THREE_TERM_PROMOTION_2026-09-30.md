# Three-term promotion test report — 2026-09-30

## Scope attempted

- Local app: `http://localhost:59594/#/login`
- Intended accounts: administrator, Head Teacher, two teachers, two students,
  and two guardians.
- Intended workflow: three terms of assessment marks, annual average,
  automatic promotion or weeding flag, and notifications.

## Environment result

- The local app was opened in an isolated Microsoft Edge session.
- The page reported the title `School Management System` and loaded the
  Flutter web canvas.
- Automated interaction with the Flutter canvas was unavailable in this test
  environment, so login, account creation, and remote Supabase writes were
  not executed.
- A production web build and focused Flutter test run were requested to
  verify the project, but permission to run them was declined. They were not
  run.
- The previous finance compilation error was fixed before this test attempt:
  `record_payment_page.dart` now calls `listFeeStructures()` with no argument.

## Result: promotion workflow cannot pass yet

The requested automatic promotion workflow is not implemented. This is a
product gap, not a failed test-data entry.

| Requirement | Current behaviour | Status |
|---|---|---|
| Record teacher assessment marks | Teachers can create assessments and enter grades for their assigned class-subject. | Available |
| Student subjects inherited from assigned class | Registration attempts to create `studentsubject` rows from class assignments. | Available after migration 0033 |
| Combine all three terms and all subjects into one annual percentage | No calculation service, database function, or grade-entry trigger exists. | Missing |
| Promote students at 50% or above | `PromoteStudentPage` is a manual class-placement screen. | Manual only |
| Flag students below 50% | `WeedingReviewsPage` requires a user to create a review and type the average. | Manual only |
| Show promoted students and annual averages to admin and Head Teacher | No annual-results list or dashboard notification producer exists. | Missing |
| Notify the guardian after promotion | Notifications are manually sent guardian messages; no promotion event creates one. | Missing |
| Ensure the operation is safe to run twice | No annual-promotion job exists to make idempotent. | Missing |

## Code evidence

- `lib/features/progression/data/progression_repository.dart` creates and
  decides a `progressionreview`, but never calculates marks or changes a
  class placement.
- `lib/features/students/presentation/promote_student_page.dart` requires a
  person to choose the target academic year and class, then saves the
  placement manually.
- `lib/features/weeding/data/weeding_repository.dart` accepts a manually
  supplied cumulative average.
- `lib/features/communications/data/communications_repository.dart` can send
  a guardian notification, but no promotion workflow calls it.

## Required next implementation

1. Add a server-side annual-results function that validates complete grades
   for all assigned subjects and Terms 1-3, then calculates percentage marks.
2. Make the function create exactly one promotion or weeding outcome per
   student/year.
3. Move promoted students to the matching next-form class for the next school
   year and copy the new class's subject enrolments.
4. Add a dashboard result list for the administrator and Head Teacher.
5. Create promotion notifications for administrator, Head Teacher, and every
   linked guardian.
6. Add automated integration tests with the Alice (70%) and Brian (40%) data
   from `TEST_PLAN_THREE_TERM_PROMOTION_AND_WEEDING.md`.
