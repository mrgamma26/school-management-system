# Live Browser Test Report — 2026-10-07

## Test environment

- Current Flutter release build served at `http://localhost:8091`.
- Browser automation used Microsoft Edge through Playwright.
- Tests used the configured Supabase development project.
- No account passwords or access tokens are recorded in this report.

## Results

### Teacher-only assignment dropdown — PASS

- Administrator login succeeded.
- The Class Assignments page loaded for 2026/2027 Form 1 Term 1.
- The Add Class Assignment dialog opened successfully.
- The Teacher dropdown displayed two staff members.
- The underlying joined query returned two rows, and both linked roles were
  `TEACHER`.
- No Accountant, Administrator, Head Teacher, Guardian, or Super User appeared
  in the dropdown.

### Teacher authentication and assessment setup — PARTIAL PASS

- Teacher login succeeded and redirected to the Teacher dashboard.
- The teacher had class-subject assignments.
- The assessment create request succeeded or found the existing matching E2E
  assessment.
- Saving draft grades failed before any grade rows were accepted.

Failure returned by the live database:

```text
invalid input value for enum grade_status_enum: "PRESENT"
```

The application and progression SQL use `PRESENT`, but the deployed database
enum does not accept that value. Draft saving, grade submission, missing-subject
progression checks, annual averages, and late-admission calculations cannot be
tested end to end until the schema is reconciled.

### Unassigned-teacher security — PASS

- An authenticated teacher attempted to create an assessment for a
  class-subject assigned to another teacher.
- Supabase rejected the request with HTTP 403.
- No unauthorized assessment remained in the database.

### Accountant workflow — BLOCKED

- The Accountant account is documented in the project checklist.
- The documented credentials were rejected by the live authentication service.
- Fee structure, payment entry, All Payments, student history, and Guardian
  Payment History checks were not executed.

### Head Teacher progression workflow — BLOCKED

- The Head Teacher account is documented in the project checklist.
- The documented credentials were rejected by the live authentication service.
- The database currently returned no progression review row for authorization
  testing.
- Promotion, retention, duplicate-promotion, missing-mapping, placement,
  subject-assignment, audit, and Guardian status checks were not executed.

### Progression authorization — NOT RUN

- Teacher and Administrator decision-write checks require an existing
  progression review row.
- No progression review was present, so the test stopped without fabricating a
  review or decision.

## Required before continuing

1. Reconcile the deployed grade status enum with the application value
   `PRESENT`.
2. Provide or reset valid Accountant and Head Teacher test credentials.
3. Generate at least one pending progression review after valid submitted grades
   exist.

After those items are resolved, resume from Save Draft Grades and continue
through payment, progression, late-admission, duplicate-placement, and
configuration-error scenarios.
