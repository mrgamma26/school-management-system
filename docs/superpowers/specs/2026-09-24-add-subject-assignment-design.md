# Add Subject Assignment

## Goal
Make the class-assignment workflow explicit: administrators add an existing subject assignment by selecting an academic year, class, subject name, and teacher.

## Behavior
- The class-assignment page shows a labeled `Add Subject` button after an academic year is selected.
- The dialog requires class, subject, and teacher selections before inserting into `classsubject`.
- Administrators and super users can add and remove assignments.
- Teachers can view assignments but do not see management controls.
- Role menus continue to expose only routes allowed for each role.

## Validation
- The page compiles with no analyzer errors.
- The live class-assignment route loads without Supabase request failures.
- The button remains hidden until an academic year is selected and the current role can manage assignments.
