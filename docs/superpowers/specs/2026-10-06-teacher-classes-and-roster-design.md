# Teacher Classes and Roster Design

## Goal

Give teachers a direct, read-only view of their own teaching classes and the
students enrolled in each assigned class. Administrators retain the existing
assignment-management experience.

## Teacher classes page

When the signed-in user has the `TEACHER` role, the existing Class Assignments
route operates in teacher mode:

- The page and app-bar title are `Classes You Teach`.
- It has no Academic Year selector and no add, edit, or remove controls.
- It fetches only assignments linked to the signed-in teacher's staff record.
- Assignments are grouped by the pair of academic year and class. A class that
  has several subjects appears once in that academic year, with its taught
  subjects displayed together.
- Each class group includes a `View Students` action.
- Empty, loading, and error states use teacher-oriented, plain-language copy.

Classes are not merged across academic years. The academic year remains visible
on each group so the roster is always unambiguous.

## Teacher roster page

Selecting `View Students` opens a dedicated, read-only page for the selected
class and academic year:

- The page queries students from active `studentclasshistory` records for the
  supplied class and academic year.
- It displays the class and academic year in its title or header.
- Teachers cannot register, edit, delete, export, or switch to another class
  or academic year from this page.
- The route receives the class ID and academic-year ID from a teacher assignment
  rather than accepting arbitrary filters from the teacher interface.

## Administrator and Super User behavior

For `SUPER_USER`, `SYSTEM_ADMIN`, `ADMINISTRATOR`, and `ADMIN`, the route
continues to be named `Class Assignments`, with its Academic Year selector and
assignment-management controls unchanged.

## Security and verification

- The data provider continues to scope teacher assignments through the current
  user's staff record.
- The roster UI is read-only. Existing Supabase row-level security remains the
  server-side authority for student access.
- Verify a teacher sees only their assigned class groups and subjects.
- Verify a class's roster lists only its active students for the group’s year.
- Verify a teacher cannot see assignment management or roster mutation actions.
- Verify an administrator still has the existing assignment management flow.
