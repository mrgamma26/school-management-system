# Teacher-only class assignment dropdown

## Goal

The **Add Class Assignment** dialog must list only active users whose school
role is `TEACHER`. Head Teachers, Accountants, Administrators, Guardians, and
staff without an active Teacher user account must not be selectable.

## Design

The assignment page provider resolves the `TEACHER` role ID, loads active
system users with that role, and then loads only staff profiles linked to those
user IDs. The dialog continues to display the staff member's first and last
name and stores the staff ID in `classsubject`.

Filtering happens before the dropdown is built, rather than loading all staff
and hiding entries in the widget. Existing class assignments are unchanged.
If there are no eligible teachers, the dialog displays a clear message instead
of an empty dropdown.

## Validation

- Teacher and Teacher 2 appear in the dropdown.
- Head Teacher and Accountant do not appear.
- Selecting an eligible teacher saves the existing `classsubject` assignment.
- No-teacher and database-error states remain understandable.
