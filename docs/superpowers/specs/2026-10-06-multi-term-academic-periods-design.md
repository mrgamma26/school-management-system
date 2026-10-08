# Multi-Term Academic Periods

## Purpose

Support Terms 1–3 as distinct academic periods so assignments, assessments,
grades, enrolments, and later progression calculations are correctly scoped.

## Design

The existing `academicyear` table remains the period source of truth. One row
represents one term: for example 2026 / TERM_1, 2026 / TERM_2, and 2026 /
TERM_3. The existing unique `(academicyear, term)` constraint preserves this
model.

The Academic Year form exposes a required Term dropdown with TERM_1, TERM_2,
and TERM_3. It validates that start and end dates are ordered and that a new
period does not overlap another period in the same school year. The list shows
both the school-year label and term.

Existing class-subject assignments, student class history, student subjects,
assessments, and grades continue to reference the period row they already use.
Teachers resolve the currently active term from the date and see only their
assignments for that period.

## Validation

Verify an administrator can create all three 2026 terms and 2027 Term 1;
duplicate term creation is rejected; overlapping term dates are rejected; the
active teacher workspace resolves the current term; and assignments remain
isolated by term.
