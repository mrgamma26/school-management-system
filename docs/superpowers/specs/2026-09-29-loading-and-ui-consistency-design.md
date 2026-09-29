# Loading and UI Consistency, Phase One

## Scope

Improve loading feedback and consistency across the admin, student, finance,
teacher, and guardian experiences. The work uses the existing shared skeleton
components and does not redesign unrelated workflows or database behavior.

## Loading system

Each page uses a skeleton that matches its eventual layout while data is
loading:

- Dashboards use summary-block and recent-activity skeletons.
- Lists use row skeletons sized to their real list items.
- Forms use field and action-button skeletons.
- Detail pages use header, information-row, and tab-content skeletons.
- Calendar and report pages use their existing structural placeholders rather
  than a generic spinner.

Inline operations such as saving, deleting, or refreshing retain compact
progress controls because the loaded page remains useful context.

## Priority surfaces

Phase one covers these user-facing areas:

- Admin: dashboards, user management, permissions, and audit log.
- Students: list, registration, detail, guardians, subjects, and class history.
- Finance: fee structures, payments, accounts, and adjustments.
- Teacher: dashboard, teaching assignments, assessments, grades, and comments.
- Guardian: dashboard, progress, report cards, and payment history.

## UI improvements

Pages use a consistent structure: explicit title, concise supporting text only
where needed, primary action near the page title or as a clear floating action,
search and filters before long lists, and purposeful empty states that explain
the next action.

Long records use aligned trailing actions and compact status labels. Forms
preserve entered values after validation and network errors. Buttons keep a
stable size while saving. Tables and mobile list rows expose the key record
information before secondary metadata.

## Accessibility and responsiveness

Skeletons preserve approximate content dimensions to avoid layout shifts.
Interactive actions keep tooltips and readable labels. Long rows reflow on
narrow screens instead of overflowing, and loading indicators do not block
navigation or hide page context unnecessarily.

## Validation

For every priority page, verify its initial loading state, empty state, error
state, success state, and a narrow web viewport. Confirm no bottom overflow,
all primary actions remain reachable, and no generic full-page spinner remains
where a page-specific skeleton is appropriate.
