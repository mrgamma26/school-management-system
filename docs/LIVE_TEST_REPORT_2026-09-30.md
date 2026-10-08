# Live test report — 30 September 2026

## Verified in the running app

1. Signed in with `admin@school.com` using the password supplied for this
   test.
2. Created academic year `2026/2027`.
3. Created `Form 1 A` and `Form 2 A`.
4. Created Mathematics and English.
5. Created the Head Teacher, Mathematics Teacher, and English Teacher staff
   accounts.
6. Assigned Mathematics to Math Teacher for Form 1 A.
7. Assigned English to English Teacher for Form 1 A.
8. Registered a student with a primary guardian, academic year, and Form 1 A.
9. Opened **Manage Subjects** for that student. The app showed both inherited
   subjects, with their assigned teachers and Form 1 A:
   - Mathematics — Math Teacher — Form 1 A
   - English — English Teacher — Form 1 A

## Resolved during the release test

- **Assessments access:** the administrator menu no longer displays
  Assessments. Direct navigation to `/assessments` redirects the administrator
  to `/admin/home`.

## Issues found

1. **Subject creation does not become visible after save.**
   - Trigger: Admin opened Subjects, selected Add Subject, entered
     `Integrated Science E2E`, and selected Create Subject.
   - Observed result: the app returned to the Subjects list without an error,
     but the list still showed only Mathematics and English after waiting and
     navigating back to the page.
   - Expected result: the new subject must appear immediately, or the page
     must show the database error that prevented saving it.
   - Impact: blocks the new subject, teacher assignment, assessment, and
     grade-entry test sequence.

2. **Super User cannot reset a staff password in User Details.**
   - The Reset Password action is hidden because the deployed Super User role
     is missing `users:reset_password`.
   - Repair SQL is available in
     `supabase/manual/grant_super_user_password_reset.sql`.
   - Impact: blocks repeatable first-login password-change testing for staff
   accounts whose generated temporary passwords were not retained.

3. **Super User is missing the Finance menu and fee-management action.**
   - Trigger: opened the release-mode administrator navigation and then
     navigated directly to Fee Structures.
   - Observed result: Finance is absent from the navigation. The Fee
     Structures screen renders its empty state but offers no Add Fee action.
   - Expected result: Super User should have Finance navigation and an Add Fee
     action for school-wide academic-year-and-term fees.
   - Likely cause: the deployed Super User permissions do not include the
     finance permissions expected by the UI.

## Additional release-mode checks passed

- Calendar loads a complete month grid from day 1 through day 30 and shows
  the event-type legend plus the administrator Add Event action.
- Class Assignments loads and requests an academic year before displaying
  assignments.
- Fee Structures correctly labels fees as school-wide and tied to academic
  year and term, rather than class.

## Not yet live-tested

- Teacher sign-in and the teacher assessment/grade-entry workflow. This needs
  a teacher session after the generated account password is used and changed.
- Head Teacher review, three-term average calculation, automatic promotion,
  automatic weeding flagging, and guardian promotion notification. These
  automatic annual-result rules are not present in the current implementation;
  existing progression and weeding screens are manual reviews.
