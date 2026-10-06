# Assignment Access and Academic Year Feedback Design

## Class assignment access

The Class Assignments page has two modes:

- `SUPER_USER`, `ADMINISTRATOR`, and `ADMIN` can add, edit, and remove
  class-subject teacher assignments.
- `TEACHER` users see only assignments that belong to their own staff record.
  The page is read-only: it does not show Add Teacher to Subject, edit, or
  remove controls.

The role check applies consistently to every assignment-management control;
the existing data provider continues to scope teachers to their own
assignments.

## Academic Year feedback

The Academic Year editor no longer exposes the local draft/autosave indicator.
It may retain entered values while the page is open, but it must not imply that
the academic year has been created before the administrator submits it.

Creation and update failures use concise, action-oriented messages:

- Duplicate year: `This academic year already exists. Choose a different starting year.`
- Permission failure: `You do not have permission to create an academic year. Ask a Super User for access.`
- Network failure: `We could not save the academic year. Check your connection and try again.`
- Other failures: `We could not save the academic year. Please try again.`

Successful creation retains the existing clear success message. The page does
not display raw Supabase/Postgres text to staff.

## Verification

- A teacher sees only their assignments and no management actions.
- An administrator sees all assignments and all management actions.
- The Academic Year page does not display `Saved just now`.
- Duplicate, permission, and network failures display the intended user-facing
  messages.
