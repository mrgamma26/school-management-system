# Admin Class Setup and Clean Reset Design

## Goal

Repair the administrator class setup flow so an administrator can create a
class and immediately use it in class assignments. Provide a destructive,
transactional reset script that preserves `admin@school.com`, roles, and role
permissions while removing all other school data.

## Approved approach

Use the full repair rather than a button-only or data-only workaround.

1. Restore `class_assignment_page.dart` from its tracked Git version because
   its current working-tree contents are empty.
2. On the Classes page, determine management access from the established
   school-admin roles plus `academics:write`. Show exactly one Add Class action:
   the bottom-right floating action button. Do not duplicate it in the app bar
   or empty state.
3. Require a Form level when creating or editing a class. Class assignments
   are scoped by the selected academic period's form, so accepting an
   unconfigured form would create records that cannot be assigned.
4. In the assignment dialog, filter classes by the selected academic period's
   form. If none match, explain the mismatch and offer a Create Class action
   that returns to the assignment flow and refreshes its class list.
5. Keep teacher assignment behavior and existing role scoping unchanged.

## Data flow and error handling

The Classes page routes to the existing class form and refreshes its provider
after the route returns. The class form validates both form level and class
name before calling `AcademicRepository.createClass` or `updateClass`.

The assignment page derives the selected period form from the academic-year
row. It must never open the assignment dialog without a configured form. An
empty matching-class list is treated as a recoverable setup state, not a
generic database error. Database and permission errors continue through the
existing repository/error handling.

## Clean-reset script

Create a manual Supabase SQL script guarded by a check that
`admin@school.com` exists. Within one transaction, delete dependent school
records in foreign-key-safe order, remove every non-preserved `systemuser`,
delete every other `auth.users` row, and keep roles and role permissions. End
with verification counts. The script is manually run in the Supabase SQL
Editor and is not an application migration.

## Verification

- Format all changed Dart files.
- Run Flutter static analysis on the affected files or project.
- Run relevant tests if present.
- Review the SQL against the final schema and verify its count query expects
  exactly one auth/system user and zero school-data rows.

## Scope

No new database tables, role model, or navigation architecture. No live data
is deleted by implementation; the user receives a manual destructive script.
