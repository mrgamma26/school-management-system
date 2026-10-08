# Approved school access, calendar and academic-year changes

The user approved proceeding after reviewing the project summary and proposed changes.

1. Reviews appear only for HEAD_TEACHER. Enforce this in both navigation definitions and route access.
2. Academic-year labels show start/end years (2026/2027). Remove the Form selector. Keep legacy term values internally for compatibility with existing reports and foreign keys; never merge or delete historical records automatically.
3. Only SUPER_USER and ADMINISTRATOR (plus existing admin aliases) can manage calendar events. Add an authenticated-user author column, retaining historical staff authors. This removes the requirement for an admin to have a staff profile. Apply matching database policies.
4. Selecting a calendar day opens the admin editor in a responsive popup. The editor supports additional nonconsecutive dates with shared event details and times; existing continuous multi-day events remain supported. Batch selected dates in one database insert.
5. Long-pressing any calendar day shows full event details for all roles. Event-card taps remain available. Query events overlapping a month using local month boundaries.
6. Verify role rules, navigation, academic labels, event serialization and month boundaries with tests; run Flutter analysis and compile the web app. Report deployed database status separately from local implementation.

Implementation order: shared role rules and navigation; academic labels/form; database migration and calendar repository/model; editor and day details; regression tests and runtime checks.
