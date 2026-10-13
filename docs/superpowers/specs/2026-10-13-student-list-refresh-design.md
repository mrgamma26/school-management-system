# Student List Refresh Design

Date: 2026-10-13

## Goal

Ensure that a student created or edited by an administrator appears on the Students page immediately, without requiring a browser restart or relying on a manual refresh.

## Confirmed cause

The live database and row-level security are returning the expected data:

- The database contains three students.
- The active super-user session can select all three students.
- The Students page does not apply an additional administrator-only filter.

The failure is client-side caching. The Students page owns a private `FutureProvider` that is not automatically disposed. After that provider has loaded an empty list once, navigating away and returning can reuse the cached empty result. The registration page inserts the student but does not invalidate the list provider.

## Approved behavior

After a successful create or edit:

1. The shared student-list provider is invalidated.
2. The next visit to the Students page fetches current rows from Supabase.
3. The existing refresh button remains available for an explicit reload.
4. If later registration steps fail, a student whose core record was successfully inserted still becomes visible in the list.

## Design

### Shared providers

Create `lib/features/students/presentation/student_providers.dart` containing:

- `studentRepositoryProvider`, the single overridable provider for `StudentRepository`.
- `studentListProvider`, a public `FutureProvider.autoDispose` that calls `listStudents()` through the shared repository.

The list and form pages will import these providers instead of declaring separate private repository/list providers. The public providers also give tests one stable override point.

### Student list page

`student_list_page.dart` will watch `studentListProvider` from the shared provider file.

No visual redesign is required. Search, status filtering, sorting, the empty state, error state, and manual refresh stay as they are. The refresh action continues to call `ref.invalidate(studentListProvider)`.

Using `autoDispose` prevents an old page instance from retaining stale results indefinitely after navigation. Explicit invalidation remains necessary because registration and editing can complete while another listener still exists.

### Student create and edit flows

`student_form_page.dart` will use `studentRepositoryProvider` for all student repository work.

For creation, invalidate `studentListProvider` immediately after `createStudent` returns successfully. This is deliberately before class placement, subject enrolment, and guardian processing. The student row already exists at that point, so the list must reflect it even if a later optional step reports an error.

For editing, invalidate `studentListProvider` immediately after the core student update succeeds so name, status, and other list-visible changes are refreshed.

Navigation behavior remains unchanged.

## Failure handling

- A failed student insert does not invalidate the list because no record changed.
- A successful insert followed by a class, subject, or guardian error does invalidate the list because the student record exists.
- A failed list reload continues to use the existing error UI and retry behavior.
- No database migration or RLS policy change is required for this repair.

## Tests

Add or update tests to verify:

1. The Students page reads through the shared provider.
2. Invalidating `studentListProvider` causes a fresh repository request.
3. A successful create invalidates the student list before later registration work.
4. A successful edit invalidates the student list.
5. Existing registration tests override the shared repository provider successfully.

Run focused student tests first, followed by Flutter analysis and the broader test suite where practical.

## Files expected to change

- `lib/features/students/presentation/student_providers.dart` (new)
- `lib/features/students/presentation/student_list_page.dart`
- `lib/features/students/presentation/student_form_page.dart`
- Relevant student presentation tests

## Out of scope

- Database schema or RLS changes
- Student registration form redesign
- Report-page loading behavior
- Changing class or subject enrolment rules
- Deleting or modifying existing student records

## Acceptance criteria

- A newly registered student appears when the administrator reaches the Students page.
- Editing a student is reflected on the next list display.
- The manual refresh button still reloads the list.
- Empty and error states continue to work.
- No duplicate network calls are introduced during a normal stable page render.
