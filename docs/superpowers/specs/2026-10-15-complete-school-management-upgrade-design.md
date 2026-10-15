# Complete School-Management Upgrade Design

**Date:** 2026-10-15  
**Status:** Approved for phased implementation  
**Scope:** Flutter application, Supabase PostgreSQL/Auth/Storage/RLS/RPCs/Edge Functions, exports, and tests

## Objective

Upgrade the existing school-management application without replacing its Flutter, Riverpod, GoRouter, or Supabase architecture. The final system must provide six securely separated user experiences, normalized school-wide academic periods, assignment-scoped teacher access, audited result corrections, immutable ledger-based finance, dynamic school branding, date-led calendar management, logged notifications, and data-driven dashboards.

Students never authenticate. `SYSTEM_ADMIN` is canonicalized to `SUPER_USER`. The only supported role pair is Teacher plus Head Teacher, exposed as two separate workspaces selected through a role switcher.

## Delivery Strategy

Implement six vertical slices. Each slice proceeds through database migration, RLS and RPC authorization, Dart models and repositories, providers, UI, exports or Edge Functions where applicable, and automated tests. A slice is not complete when only its schema or UI exists.

Existing uncommitted repository changes are preserved and integrated deliberately. The migration chain remains reproducible with `supabase db reset`; committed migrations and seed data are the source of truth. The existing test database may be reset because the current form-scoped academic-period model is intentionally being replaced.

## Slice 1: Platform Foundation

### Academic-period normalization

- Replace form-scoped years with one `academic_years` record shared by Forms 1–4.
- Store reusable ordered labels in `term_definitions` and year-specific dates in `academic_year_terms`.
- Enforce valid year and term ranges, containment, ordering, non-overlap, exactly three term definitions per active year, and one current year and term.
- Activation occurs through an authorized transaction that validates all three terms before changing current flags.

### Settings, branding, and validation

- Add a singleton school-settings model with school identity, contacts, age limits, currency, receipt footer, payment methods, carry-forward policy, overdue rule, and deposit-evidence restrictions.
- Store the logo in a private or appropriately read-restricted Storage bucket and expose short-lived signed URLs where necessary.
- Provide Administrator management and Super User override with audit records.
- Load branding through a cached Riverpod provider used by login, shell, receipts, reports, PDFs, and email rendering.
- Centralize normalized input and reusable validators. PostgreSQL checks, triggers, and RPC validation repeat security-critical invariants.

### Roles and application shell

- Retain role-based routes but reconcile them with one authorization matrix shared by menu construction and route guards.
- Add an active-workspace provider for Teacher plus Head Teacher accounts; switching changes the workspace and route without merging menus.
- Use a persistent sidebar on desktop/tablet and a drawer on phones. Branding is at the top; identity, active role, switcher, and sign-out are at the bottom.
- Make `app_tokens.dart` the source of truth for the blue-and-white palette, Nunito type scale, 4-point spacing, radii, shadows, controls, tables, chips, badges, dialogs, empty states, and interaction states.

## Slice 2: Academic Setup and Staff

### Classes and subjects

- Keep one reusable subject catalogue.
- Limit class editing to class name and Form 1–4 level.
- Manage class subjects separately with one active configuration per class and subject.
- On student class enrollment, create subject enrollments for configured subjects in the same transaction. Preserve authorized manual adjustments.

### Teacher assignments

- Automatically use the current academic year.
- Allow selection of one teacher, multiple classes, and multiple configured class-subject pairs with a confirmation summary.
- Enforce one active teacher for each class-subject-year with a partial unique constraint or equivalent invariant.
- Replace an assignment transactionally: close the previous assignment, retain its history and authored records, create the new assignment, and emit audit and notification events.
- Teacher RLS derives access from current active assignments rather than UI filters.

### Staff and accounts

- Expand staff data to all required identity, employment, qualifications, experience, emergency-contact, account, and optional profile-picture fields.
- Keep account credentials exclusively in Supabase Auth and user-management Edge Functions.
- Enforce staff age 18, normalized names, Malawian phone formats, valid email, uniqueness, and database length constraints.
- Derive created date, last login, assigned classes, and assigned subjects instead of duplicating them in editable fields.

## Slice 3: Results and Academic Decisions

### Assessment results

- Teachers query only assigned class-subject combinations and their students.
- Results support year, term, form/class, subject, and assessment filters plus mark, grade, pass/fail, and competition ranking (`1, 2, 2, 4`) unless an existing verified school rule differs.
- Summary calculations use assessed results only and explicitly show number assessed, class average, high, and low.
- Printable result sheets and branded PDF/print output share a single deterministic result projection.

### Publishing and correction

- Publishing locks results at the database layer.
- A Teacher submits a correction request with a reason. A Head Teacher approves or rejects it.
- Approval opens only the requested result for one correction cycle. The Teacher supplies the corrected mark and republishes.
- An atomic RPC records old value, new value, requester, approver, reason, decision and correction timestamps, and publication state. Direct updates of published marks are rejected.

### Progression and weeding

- Head Teacher review operates on one student and includes all enrolled subjects across all three terms, annual subject averages and trends, overall term averages, missing-result warnings, attendance, and interventions when available.
- Promote, Retain, and Weed Out decisions require a reason and immutable audit record.

## Slice 4: Finance and Guardian Report Access

### Ledger model

- Model fee structures/items, student obligations, payments, allocations, reversals, adjustments/waivers, carry-forwards, arrangements/installments, deposit evidence, and reminder history as auditable entities.
- Posted payments are immutable. Corrections append a linked reversal or authorized adjustment.
- Balance is derived from obligations, allocations, valid payments, reversals, adjustments, and carry-forwards. Status is Unpaid, Partially Paid, Paid, or Overpaid/Credit.
- Add indexes for student/account, year, term, dates, statuses, and references.

### Payment workflow

- Only Accountants can open the individual payment workspace, post/reverse payments, or verify/reject deposit evidence.
- One atomic payment RPC validates amount/date/method/reference, creates payment and allocations, links evidence metadata, updates no editable aggregate balance, and returns a receipt projection.
- Partial payment is always permitted. Formal arrangements are independent records with schedules, follow-up dates, notes, status, creator, and history.
- Deposit images use configured MIME and size limits, a private bucket, strict table and Storage RLS, and signed previews.
- Administrator and Super User receive read-only financial oversight and cannot post payments.

### Overdue processing and report blocking

- An idempotent scheduled database/Edge Function process identifies unpaid or partially paid accounts after the configured due rule, records reminder attempts, and queues in-app/email notifications.
- A secure Guardian report RPC first checks linked-student ownership and current calculated balance. Positive balances return only the amount, statement link metadata, and `Pay the balance to view the report card.` No marks, grades, comments, positions, or PDF payload are returned.
- Staff academic access is unaffected by balances.

## Slice 5: Communications and Calendar

- Extend notifications with recipient, email, subject, rendered privacy-conscious message, type, related entity, queue/sent/delivery/failure timestamps and states, retry count, and failure reason.
- Domain transactions add outbox records; the email Edge Function processes them idempotently and records failures instead of losing them.
- Support result, fee/payment, receipt, overdue, event, progression/weeding, account, assignment, replacement, and correction-decision notifications.
- Calendar creation begins by selecting a date. The selected date opens an inline editor or side panel, and saved/cancelled events visibly mark calendar dates.
- Audience rules support whole school, roles, classes, and linked Guardians with RLS-enforced visibility.

## Slice 6: Dashboards, Documents, and Hardening

- Build separate real-query dashboard projections for Super User, Administrator, Head Teacher, Teacher, Accountant, and Guardian.
- Only Super User retains global header filter/action buttons. Other filters remain local to relevant charts or tables.
- Replace generic progress blocks with the required attention queue, school timeline, academic approval queue, teaching workboard, verification queue, and family snapshot.
- All finance percentages show numerator, denominator, percentage, and denominator label.
- Use tables for dense records, ledgers for finance, structured forms for entry, tabs for profiles, a calendar for events, and printable document layouts for exports.
- Add skeleton, empty, retryable error, disabled, validation, saving, success, and destructive-confirmation states through shared components.

## Authorization Model

Authorization is enforced independently at four layers: navigation visibility, GoRouter guards, repository/RPC calls, and PostgreSQL/Storage RLS. UI hiding is never treated as authorization.

- Super User: users, permissions, settings override, audit, reports, and school-wide/read-only finance oversight; no payment posting.
- Administrator: students, staff, guardians, academic setup, assignments, settings, calendar, and read-only finance oversight; no individual payment workspace.
- Head Teacher: academic oversight, publishing, correction decisions, progression/weeding, reports, calendar, and notifications.
- Teacher: current assigned classes, subjects, students, assessments, results, comments, calendar, and notifications.
- Accountant: obligations, payments, evidence verification, arrangements, statements, and finance reports.
- Guardian: linked students, permitted published reports, payment history, calendar, and notifications.

RLS authorization reads trusted database role records or trusted `app_metadata`, never user-editable metadata. Privileged functions use a fixed safe `search_path`, explicit caller checks, restricted grants, and the smallest necessary `SECURITY DEFINER` surface.

## Data and Error Flow

Pages call focused repositories through Riverpod providers. Repositories convert Supabase/database failures into typed application exceptions. Multi-record domain changes use authorized RPC transactions. UI forms normalize input before validation, display field-level errors plus a concise form-specific summary, retain user input on recoverable failure, and provide retry actions for query failures.

Exports consume the same read projections as their pages so totals, rankings, branding, and access decisions cannot drift. Edge Functions do not become an alternate business-logic store; they handle trusted Auth administration and external email delivery while database transactions remain authoritative.

## Migration and Seed Strategy

- Retain historical migrations for repository history, then add a coherent forward upgrade sequence that removes or adapts incompatible form-scoped behavior.
- Use deterministic seed data for term definitions, settings defaults, roles/permissions, payment methods, and representative test records.
- Document local reset and seed commands. Never require manual dashboard edits.
- Make triggers, job functions, outbox processing, reminders, and replacement operations idempotent.
- Run local reset/migration verification and Supabase advisors before deployment.

## Verification

Each slice includes unit/widget tests plus SQL integration checks where database behavior is decisive. The final verification covers every acceptance area in the implementation brief, including academic dates/current flags, age rules, assignments and teacher isolation, dual-role switching, publication and correction auditing, Guardian fee blocking, ledger calculations and immutability, deposit authorization, overdue idempotency, notifications, all-role route/RLS access, calendar audiences, denominator-aware analytics, and responsive shell behavior.

Required commands include:

```powershell
dart format .
flutter analyze
flutter test
supabase db reset
supabase migration list --local
supabase db advisors
```

Database commands are discovered against the installed CLI with `supabase --help` before use. Supabase deployment additionally requires applying migrations, creating/configuring private Storage buckets and secrets, deploying Edge Functions, and enabling the scheduled overdue/outbox jobs.

## Completion Rule

A feature is complete only when persistence, authorization, UI, feedback states, audit behavior, and relevant tests work together. Placeholder screens, mock dashboard values, UI-only permission checks, mutable posted payments, or frontend-only Guardian report blocking do not satisfy this design.
