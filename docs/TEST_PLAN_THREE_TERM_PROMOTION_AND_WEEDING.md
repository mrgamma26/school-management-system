# Three-term results, promotion, and weeding test plan

## Purpose

This plan creates a small, repeatable school dataset and proves the complete
academic path: setup, class-subject-teacher assignment, student registration,
three terms of marks, annual averages, promotion, weeding, and notifications.

Use the reset script first:
`supabase/manual/delete_all_users_except_admin_school_com.sql`.

It preserves only `admin@school.com`. It deliberately keeps school master
data, so remove or edit old subjects, classes, and academic years if they
would make the test confusing.

## Important current-system limitation

The application can currently create assessments, record grades, show
guardian report cards, and create manual Progression and Weeding reviews.
It does **not** yet automatically combine all three terms, promote a student,
flag a student below 50%, or create promotion notifications. The final
sections specify the expected tests for that feature once it is implemented.

The calculation rule to implement and test is:

```
annual average = average of every percentage mark
                 (score / assessment maximum x 100)
                 across all assigned subjects in Terms 1, 2, and 3

50.00% or higher = promote
below 50.00%      = flag for weeding review
```

The boundary is inclusive: exactly 50.00% promotes.

## Test accounts

Create these accounts through **User Management > Create User**. Guardians
are created while registering the students.

| Account | Role | Assignment |
|---|---|---|
| `admin@school.com` | Super User / administrator | Creates all records and receives promotion notifications. |
| `headteacher.test@school.com` | Head Teacher | Reviews flagged and promoted students. |
| `math.teacher@school.com` | Teacher | Mathematics for Form 1 A. |
| `english.teacher@school.com` | Teacher | English for Form 1 A. |
| Guardian for Alice | Guardian | Linked to Alice only. |
| Guardian for Brian | Guardian | Linked to Brian only. |

Use unique employee numbers for the three staff accounts. Save each temporary
password and complete the required password change before continuing.

## Test school data

Create one school year, displayed as **2026/2027**, with three term records:

| Record | Academic year | Term |
|---|---:|---|
| Term 1 | 2026 | TERM_1 |
| Term 2 | 2026 | TERM_2 |
| Term 3 | 2026 | TERM_3 |

Create these classes in this order:

1. Select **Form 1** and enter class name **A** to create **Form 1 A**.
2. Select **Form 2** and enter class name **A** to create **Form 2 A**.

Create these subjects:

1. Mathematics
2. English

The two-subject setup is the smallest dataset that proves the workflow. For a
real Form 1 with eight subjects, repeat each subject-assignment and grade step
for the other six subjects. Every subject must have a teacher before students
are enrolled.

## Administrator setup

1. Sign in as `admin@school.com`.
2. Confirm the three 2026 term records exist and their date ranges do not
   overlap incorrectly.
3. Create Form 1 A and Form 2 A.
4. Create Mathematics and English.
5. Create the Head Teacher and both teachers.
6. Open **Academics > Class Assignments**. For **each term**, create:
   - Form 1 A + Mathematics + Mathematics teacher.
   - Form 1 A + English + English teacher.
7. Confirm that each teacher sees only the class and subject assigned to them.
8. Register **Alice Promote** in Form 1 A during Term 1. Link one guardian.
9. Register **Brian Review** in Form 1 A during Term 1. Link a different
   guardian.
10. Confirm each student inherited Mathematics and English from Form 1 A.
    The student subject list must show both assignments without manual subject
    selection.
11. For Term 2 and Term 3, retain both students in Form 1 A and ensure they
    have a class-history/enrolment record and the two class-subject assignments
    for that term. This lets the teacher see them when entering that term's
    grades.

Expected result: both teachers can open their own assignment and see Alice and
Brian. Neither teacher can see or grade the other subject.

## Teacher grading workflow

Run the following once for each term. A teacher must use their own account.

1. Sign in as the Mathematics teacher.
2. Open **Assessments**.
3. Select the Mathematics assignment for Form 1 A.
4. Select **Add Assessment**.
5. Set type to **End of Term**, name it `Term 1 Mathematics`, and set maximum
   score to `100`.
6. Open **Enter Grades**. Use the student search and enter both results.
7. Submit the complete list and confirm the saved scores reappear after a page
   refresh.
8. Repeat the same process as the English teacher for `Term 1 English`.
9. Repeat steps 1-8 for Term 2 and Term 3.
10. Each teacher adds a brief term comment for each student where the comments
    screen is available.

Use this score sheet. All scores are out of 100.

| Term | Subject | Alice Promote | Brian Review |
|---|---|---:|---:|
| 1 | Mathematics | 70 | 40 |
| 1 | English | 70 | 40 |
| 2 | Mathematics | 60 | 45 |
| 2 | English | 60 | 45 |
| 3 | Mathematics | 80 | 35 |
| 3 | English | 80 | 35 |

Expected annual results:

| Student | Term 1 | Term 2 | Term 3 | Three-term annual average | Expected outcome |
|---|---:|---:|---:|---:|---|
| Alice Promote | 70% | 60% | 80% | 70% | Promote from Form 1 A to Form 2 A. |
| Brian Review | 40% | 45% | 35% | 40% | Flag for weeding review. |

## Current manual-review checks

Use these checks now, before automatic promotion is implemented.

1. Sign in as the Head Teacher.
2. Open Alice's grades or report card and verify the six saved marks and 70%
   annual average.
3. Open Brian's grades or report card and verify the six saved marks and 40%
   annual average.
4. Open **Progression Reviews**. Create or approve a review for Alice with
   average score `70`.
5. Open **Weeding Reviews**. Create a review for Brian with cumulative average
   `40` and an explanatory reason.
6. Confirm neither review is visible to the unrelated guardian.
7. Sign in as each guardian. Confirm that guardian sees only their own child's
   three-term report card, results, and teacher comments.

## Automatic promotion and weeding acceptance tests

Run these after the automatic annual-calculation feature is implemented.

1. Finish entering the final Term 3 mark for every subject for Alice and
   Brian.
2. Trigger the end-of-year calculation once. Re-running it must not create a
   duplicate class-history record, review, or notification.
3. Verify Alice's annual result contains all three term totals, the six
   subject marks, and a 70.00% overall average.
4. Verify the system automatically closes Alice's Form 1 A enrolment and
   creates a Form 2 A enrolment for the next academic year.
5. Verify Alice's subject enrolments change to the Form 2 A assignments for
   the new year.
6. Verify the administrator and Head Teacher each receive one notification
   saying Alice was promoted from Form 1 A to Form 2 A and showing 70.00%.
7. Verify Alice's guardian receives one promotion notification and can see
   Alice's updated class on the guardian dashboard.
8. Verify Brian remains in Form 1 A and is not promoted.
9. Verify Brian appears on the Head Teacher dashboard under **Flagged
   Students for Weeding**, showing 40.00%, all three term results, and the
   reason for the flag.
10. Verify the administrator and Head Teacher can open the flagged-student
    record, review the evidence, and make the permitted follow-up decision.
11. Verify a student with exactly 50.00% is promoted.
12. Verify a student missing even one required subject or term grade remains
    **Pending** and is neither promoted nor flagged until the record is
    complete.

## Final access and data checks

1. Sign in as each teacher and confirm they can edit only their own
   class-subject assessments and grades.
2. Confirm a teacher cannot open the other teacher's class-subject assignment
   by changing the URL.
3. Sign in as the Head Teacher and confirm the promotion and flagged lists are
   visible but staff-account management is unavailable.
4. Sign in as the administrator and confirm both lists and notifications are
   visible.
5. Sign in as each guardian and confirm that only the linked child, that
   child's report card, and that child's promotion notification are visible.
