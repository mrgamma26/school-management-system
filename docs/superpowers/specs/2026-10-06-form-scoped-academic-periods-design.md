 # Form-Scoped Academic Periods

## Purpose

Allow Form 1, Form 2, Form 3, and Form 4 to use the same school-year and term
labels while having different start and end dates. Sections within one form,
such as Form 1A and Form 1B, share the form-level calendar.

## Data model

Add a required `form` value to each `academicyear` period. Its allowed values
match the existing class form values: `FORM_1`, `FORM_2`, `FORM_3`, and
`FORM_4`. A period is uniquely identified by `(academicyear, term, form)`.

Existing rows are migrated deliberately rather than guessed. Administrators
must assign a form to legacy periods before those periods are used for new
assignments. The migration must preserve existing foreign keys and records.

## Administration workflow

The academic-period form requires school year, term, form, start date, and end
date. The list groups periods by school year and displays form, term, and date
range. Duplicate `(school year, term, form)` records are rejected.

Date-overlap validation applies only within the same school year and form.
Different forms may overlap and may have different term boundaries. Terms for
one form may not overlap each other.

## Assignments and active periods

Class-subject assignment screens show only periods whose form matches the
selected class. A Form 2 class cannot be assigned to a Form 1 period.

Teacher assessment resolution uses the teacher's assignment and its period;
it does not choose one global active academic year. An assignment is active
when today's date falls inside that assignment's form-scoped period.

Student class history and student-subject enrolment continue to reference the
selected form-scoped period through existing IDs. Grade entry remains scoped
through the class-subject assignment.

## Progression

Term and annual calculations group periods by school year and form. A learner
uses only the periods for the form in which they were enrolled. Promotion to
the next form resolves the target form's next applicable period. Late-admission
rules evaluate enrolment against that form's dates.

## Errors and validation

The UI provides clear errors for missing form configuration, duplicate periods,
overlapping periods within one form, and class/period form mismatches. Existing
records with no form are visible to administrators as requiring configuration
but are not silently matched to a class.

## Validation

Verify that all four forms can have 2026 Term 1 records with different dates;
sections in one form share the period; mismatched assignments are blocked;
teachers see assignments active for their class form; and existing assessment,
grade, enrolment, payment, and progression relationships remain intact.
