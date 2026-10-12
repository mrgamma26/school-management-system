# Calendar event save repair

## Problem

Creating a calendar event from the Flutter admin application fails with the generic message "Something went wrong." The application already sends the authenticated system-user author in `createdbyuser` and batches repeated dates through `create_calendar_events`, but migration `0031_calendar_admin_authors.sql` is corrupted: it contains plain text instead of SQL. Consequently, deployed databases can lack the author column, the RPC, and the matching row-level security policies.

## Approved approach

Repair the database with a new forward migration. Do not rewrite migration `0031`, because a deployed Supabase project may already record that migration as applied. A new migration is repeatable across development and deployed databases and preserves migration history.

The rejected alternatives are:

- Editing `0031` in place, which would not repair a database that has already marked it applied.
- Creating a staff record for each administrator, which preserves the obsolete coupling and does not restore the missing batch RPC.

## Database design

The migration will make legacy `calendarevent.createdby` nullable and add `calendarevent.createdbyuser` as a nullable foreign key to `systemuser(userid)` with `ON DELETE SET NULL`. Existing events keep their staff author; where a matching staff record has a linked system user, the migration will backfill the new author without deleting legacy data. An index on `createdbyuser` will support author lookups and deletion cleanup.

Authenticated users may continue to read calendar events. Create, update, and delete access will be limited to the normalized administrative roles accepted by the Flutter application: `SUPER_USER`, `SYSTEM_ADMIN`, `ADMINISTRATOR`, and `ADMIN`. Policies will use `TO authenticated`, `public.current_app_role()`, and both `USING` and `WITH CHECK` where applicable. No client-provided metadata claim will be trusted for authorization.

The migration will create `public.create_calendar_events(events jsonb)` as a `SECURITY INVOKER` function. It will:

1. Require an authenticated user and an authorized administrative role.
2. Require a non-empty JSON array.
3. Parse each requested event, validate the required name and time range, and insert all rows in one transaction.
4. Set `createdbyuser` from `auth.uid()` rather than trusting a value supplied by the client.
5. Return the inserted calendar rows to the Flutter repository.

Execution will be revoked from `PUBLIC` and granted to `authenticated`. Table privileges and RLS remain separate: authenticated clients receive the required table privileges, while policies enforce row authorization. The PostgREST schema cache will be notified after the function is created.

## Flutter behavior

The existing form and repository contract remain intact: one date creates one event, while additional dates are sent to the same atomic RPC. The repository will recognize missing-function, missing-column, and stale-schema-cache failures and return a specific, safe message explaining that the latest calendar database migration must be applied. Other database details will remain hidden behind the existing user-friendly error handling.

No staff profile will be required for an administrator to create an event. Existing events authored by staff remain readable and editable according to the administrator policies.

## Data flow

The event form validates the user's role and fields, builds one `CalendarEvent` per chosen date, and calls `CalendarRepository.createMany`. The repository serializes the events and invokes `create_calendar_events`. PostgreSQL revalidates authentication and authorization, replaces the supplied author with `auth.uid()`, and inserts the batch atomically. A failed row rolls back the whole batch; a successful call returns all inserted rows and the calendar refreshes.

## Error handling and compatibility

The migration will be idempotent where practical so it can repair databases with none, some, or all of the intended `0031` changes. It will not delete calendar data. Existing staff-authored rows remain valid, and deleting a system user nulls only the system-user author reference.

Validation failures and authorization failures will raise clear PostgreSQL exceptions. Flutter will show schema-specific guidance only for recognizable deployment/schema errors and a general safe message for all other unexpected failures.

## Verification

- Confirm current Supabase documentation for RLS, database functions, and schema-cache behavior before implementation.
- Create the migration through the installed Supabase CLI when available and inspect the generated file.
- Verify the function and policies with a test query or linked-project database tooling when credentials are available.
- Run relevant calendar model/repository tests and the full calendar test directory.
- Run `flutter analyze` for the calendar feature.
- Inspect migration status and run Supabase database advisors when supported by the installed CLI.
- Report separately whether the repair is only committed locally or also applied to the linked remote project.

## Out of scope

This repair does not redesign the calendar UI, change which roles can view the calendar, delete existing events, or modify unrelated class and academic-year work.
