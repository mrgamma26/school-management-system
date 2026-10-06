# Three-Term Progression Design

## Goal

Provide a trustworthy, end-to-end progression workflow. Teachers submit grades
for their assigned class subjects; the database calculates annual results from
eligible terms; and a Head Teacher makes a single auditable Promote or Retain
decision that cannot diverge from the learner's class placement.

## Scope

The work covers backend calculations, Head Teacher evidence and decision
screens, class-history placement, subject enrolment, audit records, guardian
visibility, permissions, and automated tests. Finance and unrelated calendar
features remain unchanged.

## Architecture

Use Supabase database functions as the source of truth:

1. A calculation function evaluates one learner's results for a school year.
   It returns term averages, annual average, completeness, missing evidence,
   the pass rule, a recommendation, and the proposed next class.
2. A refresh function creates or updates exactly one `PENDING` progression
   review only when the learner is eligible for review.
3. An atomic decision function validates the pending review and makes the Head
   Teacher's decision. A promotion closes the current placement, creates the
   target placement, creates the target subject enrolments, updates the review,
   records an audit event, and creates guardian visibility data in one
   transaction.

Flutter reads evidence from the calculation function and never accepts an
operator-entered annual average. The existing manual Promote / Move Class page
must not be able to bypass a pending, incomplete, or final progression review.

## Grade submission

Teachers can save grade rows as drafts while entering them. A submission action
marks an assessment's grades as submitted. Submitted grades are eligible for
progression automatically; no additional Head Teacher grade-approval stage is
required. Changes to a submitted grade reopen/recalculate the affected review
and are audited.

## Result rules

- The configured initial pass threshold is 50%, stored as a database rule
  rather than duplicated in Flutter.
- A term average is the average of normalized subject assessment scores for
  eligible subjects with complete submitted results.
- The annual average is the average of the available eligible term averages.
- Decision values are standardized to `PENDING`, `PROMOTED`, and `RETAINED` in
  migrations, repositories, UI, and tests.
- A student only needs results for a term during which they were enrolled. A
  pre-enrolment term is displayed as `—` / `Not enrolled`, is not a failure,
  and is excluded from the denominator. Thus a learner joining in Term 2 is
  averaged over Terms 2 and 3; one joining in Term 3 is averaged over Term 3.
- A missing or unsubmitted result during an enrolled term blocks a decision.
  Absent and missing grades are not silently scored as zero.
- The 50% pass threshold applies even if the annual average uses only one or
  two enrolled terms.

## Head Teacher experience

The Progression Reviews page provides school-year, class, decision status,
completion, and student-name filters. Rows display the learner, current class,
Term 1–3 averages, annual average, recommendation, and warnings.

The student evidence page displays identity, active class, proposed next
class, term-average cards, annual average, threshold, assessment-level subject
evidence, teacher comments, and missing-result notices. It requires a decision
reason. Promote and Retain remain disabled until the calculation is complete.

Promote opens a confirmation that names the learner, old and new class, target
academic period, annual average, and effect of the action. Success provides a
receipt and link to class history.

## Placement and security

Promotion resolves the next form using `formlevel` (or an explicit mapping
when the database supports one). It closes the active `studentclasshistory`
row before creating the target record. At most one active placement may exist
for a student in an academic period.

Retention records the final decision but does not create a next-form placement.
Final classes use a future graduation/completion flow rather than attempting
to resolve a nonexistent class.

Only Head Teachers, plus any explicitly configured override permission, can
decide progression. Teachers can submit grades only for their own assignments;
guardians can read outcomes only for linked learners. Guardian views show the
annual result and progression status but not confidential decision reasons.

## Error handling

The UI explains missing results, pre-enrolment terms, missing next-class
configuration, duplicate active placements, already-completed decisions, and
authorization failures. Failed decisions do not persist a partial placement,
review, audit record, subject enrolment, or notification.

## Tests

Cover successful promotion, retention, incomplete enrolled terms, late
admission with one and two eligible terms, missing subject grades, missing
target classes, duplicate decision requests, atomic rollback, permission
denial, manual-promotion blocking, and guardian outcome visibility.
