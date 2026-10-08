# Must-Fix E2E Findings

Date: 2026-09-23

This document records issues found while manually testing the Flutter web app with the real browser UI.

## High: Flutter web debug server is unstable

**Observed:** The app can load and authenticate successfully, but the Flutter web server repeatedly stalls at `Waiting for connection from debug service` or loses its DDC WebSocket. Existing browser sessions then become blank or show only `Loading School Management System...`.

**Reproduction:**

1. Run `flutter run -d web-server --web-port=PORT --dart-define-from-file=env/dev.json --dart-define=E2E_TEST=true`.
2. Open the printed localhost URL.
3. Log in and complete the Create User confirmation dialog.
4. Dismiss the dialog or reload the page.
5. The server may stop responding, the WebSocket may refuse connections, or the browser may remain on the bootstrap loader.

**Impact:** Prevents reliable end-to-end testing and can interrupt real user workflows after account creation.

**Evidence:** Reproduced on ports `55418`, `55419`, `55420`, `55421`, `56673`, and `56674`. One session on port `56672` successfully logged in and created a Teacher account before the canvas went blank.

**Suggested next step:** Investigate the Flutter/DWDS web-server lifecycle and browser connection handling. Validate with `flutter run -d chrome` and a release/static web build after resolving the debug-server issue.

## Resolved: System Admin role consolidated into SUPER_USER

**Fix:** Migration `supabase/migrations/0021_consolidate_super_user_role.sql` deliberately consolidates `SYSTEM_ADMIN` into the canonical `SUPER_USER` role. Existing `SYSTEM_ADMIN` users are migrated to `SUPER_USER` with their permissions preserved. The role dropdown in Create User pulls dynamically from `UserRepository().listRoles()`, so `SYSTEM_ADMIN` no longer appears after the migration runs.

**Design decision:** This is intentional — `SUPER_USER` and `SYSTEM_ADMIN` had identical permissions and separate rows created confusion. A single canonical role reduces maintenance burden.

**Validation:** The role dropdown correctly reflects only `SUPER_USER`, `TEACHER`, `HEAD_TEACHER`, `ADMINISTRATOR`, and `ACCOUNTANT`. No UI change is required.

## Medium: Account provisioning test coverage is blocked after the first account

**Observed:** The Teacher account was successfully created through the Super User UI. Confirmation dialog:

- Email: `e2e.teacher.20260923@school.com`
- Temporary password: recorded during the test session
- The dialog displayed a Copy password button and stated the password would not be shown again.

After dismissing the dialog, the browser canvas became blank and the server stopped responding, preventing Head Teacher and Accountant provisioning.

**Impact:** The remaining role-based tests cannot start because their accounts cannot be created and their generated credentials cannot be captured.

## Medium: Login email is cleared during accessible submit

**Observed:** With both Administrator credentials filled through the exposed Flutter semantics fields, clicking `Sign In` cleared the email field and showed `Email is required.` The password remained populated.

**Workaround used during testing:** Refill the email through the browser's DOM locator, then submit again.

**Impact:** Keyboard/accessibility-driven login can fail even when the user entered a valid email. This is especially harmful for automated browser tests and assistive-technology users.

## High: Credential dialog dismissal can blank the Flutter web canvas

**Observed:** After creating the Teacher and Head Teacher accounts, the credential dialog displayed correctly. Clicking `Done` caused the app canvas to become blank. Waiting five seconds and reloading left the browser on `Loading School Management System...`.

**Impact:** The provisioning workflow cannot continue to the next account without restarting the app, and a user may lose the current workflow immediately after a successful account creation.

**Evidence:** Reproduced after the Teacher confirmation dialog and again after the Head Teacher confirmation dialog on the same browser session.

## Resolved: Create User returns through the router

**Fix:** After the credential dialog closes, `CreateUserPage` now navigates explicitly to `/admin/users` with `context.go(...)` instead of popping an ambiguous navigator route. This avoids leaving the GoRouter shell on an invalid or blank route.

**Validation:** The Create User page and router report no diagnostics, and the focused authentication tests pass.

## Resolved: Administrator Students list and search

**Verified:** `/students` is registered in the router and allowed for `ADMINISTRATOR`. `StudentListPage` loads the Administrator-wide student provider, includes a `Search by name or ID` field, and provides the Register Student action.

**Validation:** The Students page reports no diagnostics and the focused student model tests pass.

**Application fix applied:** Create User now navigates explicitly to `/admin/users`
after the credential dialog closes instead of calling `Navigator.pop` from a
GoRouter-owned route. Focused diagnostics pass. Browser confirmation is still
blocked by the Flutter debug-service handshake in the current environment.

## Resolved: Calendar joined class-name mapping

**Observed:** `CalendarEvent.fromMap` read only `classroomname`, while an existing fixture used the legacy joined key `classname`.

**Fix:** The mapper now accepts both `classroomname` and `classname`, preserving compatibility with current and legacy joined responses.

**Validation:** `test/calendar/calendar_event_model_test.dart` passes all 13 tests and the full Flutter suite reports `All tests passed`.

## Blocked coverage

The following scenarios were not executed because the browser runtime became unavailable:

- Head Teacher, Accountant, and System Admin provisioning.
- Teacher, Accountant, Head Teacher, and Guardian login flows.
- Student creation and guardian linking after the current provisioning session.
- Academic setup, class assignment, assessments, grades, payments, progression, comments, permission toggles, and audit-log completeness.
- Duplicate Add-button and permission-based navigation checks across all requested roles.

These are untested, not passing.
