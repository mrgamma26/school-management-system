# Teacher Assignment Dropdown Design

## Scope

This change makes teacher assignment selection role-safe and removes the
redundant Teacher dashboard shortcut to the general student list.

## Assignment dialogs

The Teacher dropdown in both Add Class Assignment and Edit Assignment fetches
only staff members whose linked `systemuser` account has the `TEACHER` role.
Administrators cannot select Accountant, Administrator, Super User, Guardian,
or other non-teacher staff as a class-subject teacher.

The query performs the role filtering at the database request rather than
loading all staff and hiding rows in the interface. If no teacher staff exist,
the dropdown is empty and the existing form validation prevents assignment.

## Teacher dashboard

Remove only the `My Students` dashboard tile. Teachers open students through
`Classes You Teach` and the selected class's `View Students` action.

The Teacher sidebar navigation is outside this scope and remains unchanged.

## Verification

- Add and Edit Assignment show only staff linked to `TEACHER` accounts.
- A non-teacher staff member cannot be selected as the assigned teacher.
- The Teacher dashboard no longer displays the `My Students` tile.
- Other Teacher dashboard shortcuts and all administrator assignment controls
  remain unchanged.
