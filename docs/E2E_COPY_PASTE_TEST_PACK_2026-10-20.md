# School Management System — Copy/Paste E2E Test Pack

Date: 2026-10-20  
Run ID: `E2E-20261020-A`  
App: `http://127.0.0.1:53131`  
Starting account: `admin@school.com`  
Starting database: only the preserved admin account and the school-settings singleton

> Use this only in the Supabase test project. The emails and passwords below are disposable test values. Never reuse them for real users.

## How to use this pack

1. Complete phases in order.
2. Copy the values exactly.
3. Do not continue when a phase gate fails.
4. Reload the page after each save to prove the record persisted.
5. Do not create records with SQL to work around a failed UI flow; that would invalidate the E2E test.
6. Save screenshots and the exact error before fixing any failure.
7. Run the reset script only after all evidence has been collected.

Result labels:

- `PASS`: UI, reload, relationship, and permission assertions all passed.
- `FAIL`: actual behavior differs from expected behavior.
- `BLOCKED`: prerequisite data or relationship is missing.
- `UNVERIFIED`: the step was not performed.

## Test run record

Copy this into your notes and update it as you work:

```text
Run ID: E2E-20261020-A
Started at:
Tester:
App URL: http://127.0.0.1:53131
Supabase project: vgrztgztjqsqenxetsxb

Admin setup: UNVERIFIED
Staff creation: UNVERIFIED
Student/guardian setup: UNVERIFIED
Teacher assessment: UNVERIFIED
Head-teacher review: UNVERIFIED
Finance: UNVERIFIED
Guardian: UNVERIFIED
Academic rollover/history: UNVERIFIED
Final route sweep: UNVERIFIED
Overall: UNVERIFIED
```

## Phase 0 — baseline

Sign in with:

```text
Email: admin@school.com
Password: use the existing preserved admin password
```

Before continuing, confirm:

- the admin dashboard opens;
- Students, Staff, Guardians, Payments, Assessments, and Notifications have no test records;
- School Settings opens successfully;
- the login page does not display “Management Portal”;
- there are no browser console errors or failed Supabase requests.

Gate 0: only continue if `admin@school.com` can reach the Super User/admin workspace.

## Phase 1 — school settings

Open **School Settings** and paste:

```text
School name: E2E Academy 20261020
Motto: Learning with integrity
Physical address: 10 E2E Test Road, Blantyre
Postal address: P.O. Box 20261020, Blantyre
Phone number: +265 991 111 111
Email address: office.e2e@example.com
Website: https://example.com/e2e-academy
Default currency: MWK
Receipt footer: E2E TEST RECEIPT — NOT A REAL PAYMENT
Balance carry-forward policy: NEXT_TERM
Overdue day of term: 30
Deposit slip maximum size: 5242880
Accepted deposit types: image/jpeg, image/png, image/webp
```

Expected:

- save succeeds;
- reload shows `E2E Academy 20261020`;
- after logout, the large login headline shows `E2E Academy 20261020`;
- only the icon appears above it;
- no small duplicate school name and no “Management Portal” appear.

Gate 1: stop if the name disappears after reload.

## Phase 2 — academic years and terms

### 2A. Current year

Create this year and select **Make current**:

```text
Academic year name: 2026/2027
Start date: 2026-09-01
End date: 2027-07-31
Make current: Yes

Term 1 start: 2026-09-01
Term 1 end: 2026-12-18

Term 2 start: 2027-01-04
Term 2 end: 2027-04-16

Term 3 start: 2027-04-26
Term 3 end: 2027-07-30
```

Expected:

- one normalized academic year and exactly three terms are saved;
- period selectors show 12 distinct current-year choices: three terms × four forms;
- labels include year, term, and form, for example `2026/2027 · Term 1 · Form 1`.

### 2B. Next year

Create this year but do **not** make it current:

```text
Academic year name: 2027/2028
Start date: 2027-09-01
End date: 2028-07-31
Make current: No

Term 1 start: 2027-09-01
Term 1 end: 2027-12-17

Term 2 start: 2028-01-03
Term 2 end: 2028-04-14

Term 3 start: 2028-04-24
Term 3 end: 2028-07-28
```

Expected:

- `2026/2027` remains the only current year;
- `2027/2028 · Term 1 · Form 2` exists as a future promotion destination;
- editing and resaving a year does not delete its term records.

Gate 2: stop if any period selector is empty or shows repeated labels without term/form.

## Phase 3 — classes and subjects

Create these classes:

```text
Class 1
Class name: E2E Form 1A
Form: FORM_1 / Form 1

Class 2
Class name: E2E Form 2A
Form: FORM_2 / Form 2
```

Create these subjects:

```text
Subject 1
Subject name: E2E Mathematics
Description: Mathematics subject for E2E-20261020-A

Subject 2
Subject name: E2E English
Description: English subject for E2E-20261020-A
```

Expected:

- two classes and two subjects remain after reload;
- duplicate names are rejected or safely resolved;
- Form 1 academic periods show only `E2E Form 1A` during student placement;
- Form 2 academic periods show only `E2E Form 2A`.

Gate 3: stop if a Form 1 period allows selecting `E2E Form 2A`.

## Phase 4 — fees and payment channels

### 4A. Fee structures

Create both fees against this exact period:

```text
Academic period: 2026/2027 · Term 1 · Form 1
```

Fee 1:

```text
Fee type: E2E Tuition
Amount (MWK): 1200.00
```

Fee 2:

```text
Fee type: E2E Exam Fee
Amount (MWK): 300.00
```

Expected total fees for a Form 1 Term 1 student: `MWK 1,500.00`.

### 4B. Bank channel

```text
Channel Type: Bank Account
Display Label: E2E Main Fees Account
Bank Name: E2E National Bank
Masked Account Number: ****2001
Currency: MWK
Status: Active
```

### 4C. Mobile-money channel

```text
Channel Type: Mobile Money
Display Label: E2E Airtel Fees
Mobile Provider: Airtel Money
Masked Till / Wallet Number: ****1111
Currency: MWK
Status: Active
```

Expected:

- both fees survive reload;
- both active channels appear for their matching payment methods;
- no PIN, full account number, or secret is stored;
- zero or negative fee amounts are rejected.

Gate 4: stop if the fee period is not the exact Form 1 period or channels do not appear.

## Phase 5 — staff accounts

If the form generates a temporary password automatically, use the generated password and record it in your private run notes. If the form allows a password, use the test password below.

### 5A. Administrator

```text
First name: E2E
Last name: Administrator
Gender: FEMALE
Date of birth: 1990-01-15
Phone number: +265 991 200 001
Physical address: 20 Admin Test Road, Blantyre
Email: e2e.admin.20261020@example.com
Role: ADMINISTRATOR
Temporary password: E2E!Admin2026Aa
Permanent test password: E2E!Admin2026Bb
```

### 5B. Mathematics teacher

```text
First name: E2E
Last name: Math Teacher
Gender: MALE
Date of birth: 1992-02-20
Phone number: +265 991 200 002
Physical address: 21 Teacher Test Road, Blantyre
Email: e2e.math.teacher.20261020@example.com
Role: TEACHER
Temporary password: E2E!Math2026Aa
Permanent test password: E2E!Math2026Bb
```

### 5C. English teacher

```text
First name: E2E
Last name: English Teacher
Gender: FEMALE
Date of birth: 1991-03-21
Phone number: +265 991 200 003
Physical address: 22 Teacher Test Road, Blantyre
Email: e2e.english.teacher.20261020@example.com
Role: TEACHER
Temporary password: E2E!English2026Aa
Permanent test password: E2E!English2026Bb
```

### 5D. Head teacher

```text
First name: E2E
Last name: Head Teacher
Gender: FEMALE
Date of birth: 1985-04-22
Phone number: +265 991 200 004
Physical address: 23 Head Test Road, Blantyre
Email: e2e.head.20261020@example.com
Role: HEAD_TEACHER
Temporary password: E2E!Head2026Aa
Permanent test password: E2E!Head2026Bb
```

### 5E. Accountant

```text
First name: E2E
Last name: Accountant
Gender: MALE
Date of birth: 1988-05-23
Phone number: +265 991 200 005
Physical address: 24 Accounts Test Road, Blantyre
Email: e2e.accounts.20261020@example.com
Role: ACCOUNTANT
Temporary password: E2E!Accounts2026Aa
Permanent test password: E2E!Accounts2026Bb
```

For every staff account:

1. Sign out from admin.
2. Sign in with the temporary/generated password.
3. Confirm password change is required.
4. Change to the listed permanent test password.
5. Confirm the correct dashboard opens.
6. Sign out before testing the next account.

Gate 5 expected counts:

```text
Auth users: 6 (preserved admin + 5 staff accounts)
System users: 6
Staff profiles: 5
```

## Phase 6 — class subjects and teacher assignments

As `admin@school.com`, configure:

```text
Class: E2E Form 1A
Subjects:
- E2E Mathematics
- E2E English
```

Assign:

```text
Academic year: 2026/2027
Class: E2E Form 1A
Subject: E2E Mathematics
Teacher: E2E Math Teacher
Status: Active
```

```text
Academic year: 2026/2027
Class: E2E Form 1A
Subject: E2E English
Teacher: E2E English Teacher
Status: Active
```

Expected:

- Mathematics teacher sees only Mathematics;
- English teacher sees only English;
- each assignment is bridged to all three current-year Form 1 legacy term periods;
- neither teacher can read or edit the other teacher's assignment through a direct URL.

Gate 6: stop if either teacher sees both subjects or no assignment.

## Phase 7 — students and guardians

Guardians are created inside student registration. Do not look for a separate “New Guardian” button.

### 7A. Student A1 and Guardian A

Student:

```text
First name: Amina
Middle name: E2E
Last name: Banda
Gender: FEMALE
Date of birth: 2012-05-14
Physical address: 30 Family A Test Road, Blantyre
Enrollment status: ENROLLED
Academic period: 2026/2027 · Term 1 · Form 1
Class: E2E Form 1A
```

New guardian in the same form:

```text
First name: Grace
Last name: Banda
Gender: FEMALE
Email: e2e.guardian.a.20261020@example.com
Phone number: +265 991 300 001
Physical address: 30 Family A Test Road, Blantyre
Relationship: Mother
Permanent test password after first login: E2E!GuardianA2026
```

Copy the generated temporary guardian password from the success dialog into private run notes.

Expected relationships:

- Amina has one active Form 1A class-history row;
- the academic-period form is `FORM_1`;
- Mathematics and English subject-enrolment rows exist;
- Guardian A is linked to Amina exactly once.

### 7B. Student A2 with existing Guardian A

```text
First name: Bilal
Middle name: E2E
Last name: Banda
Gender: MALE
Date of birth: 2013-06-15
Physical address: 30 Family A Test Road, Blantyre
Enrollment status: ENROLLED
Academic period: 2026/2027 · Term 1 · Form 1
Class: E2E Form 1A
Guardian: select existing Grace Banda
Relationship: Mother
```

Expected: no second Grace Banda guardian/account is created.

### 7C. Student B1 and Guardian B

Student:

```text
First name: Cara
Middle name: E2E
Last name: Moyo
Gender: FEMALE
Date of birth: 2012-07-16
Physical address: 31 Family B Test Road, Blantyre
Enrollment status: ENROLLED
Academic period: 2026/2027 · Term 1 · Form 1
Class: E2E Form 1A
```

New guardian:

```text
First name: Peter
Last name: Moyo
Gender: MALE
Email: e2e.guardian.b.20261020@example.com
Phone number: +265 991 300 002
Physical address: 31 Family B Test Road, Blantyre
Relationship: Father
Permanent test password after first login: E2E!GuardianB2026
```

Gate 7 expected counts:

```text
Auth users: 8
System users: 8
Staff profiles: 5
Guardians: 2
Students: 3
Student-guardian links: 3
Active Form 1A placements: 3
Expected subject enrolments: 6
```

Both teachers must now see exactly Amina, Bilal, and Cara for their own subject. Stop if either roster is empty.

## Phase 8 — teacher assessment regression

### 8A. Mathematics teacher login

```text
Email: e2e.math.teacher.20261020@example.com
Password: E2E!Math2026Bb
```

Confirm before creating anything:

- only `E2E Form 1A — E2E Mathematics` is available;
- English is not available;
- roster contains exactly Amina Banda, Bilal Banda, and Cara Moyo.

### 8B. Create assessment

```text
Class/subject: E2E Form 1A — E2E Mathematics
Assessment name: E2E Term 1 Mathematics Test
Assessment type: TEST
Maximum score: 100
```

Negative checks first:

- blank name is rejected;
- maximum `0` is rejected;
- maximum `-1` is rejected.

### 8C. Enter marks

```text
Amina Banda: 80
Bilal Banda: 55
Cara Moyo: mark ABSENT; leave score blank
```

Checks before submission:

1. Wait for the visible saved state after every row.
2. Reload the page.
3. Confirm `80`, `55`, and ABSENT remain.
4. Try `101` and `-1`; both must be rejected and must not replace the last valid value.
5. Confirm one grade row per student; no duplicates.

Submit the assessment.

Expected:

- every grade changes from DRAFT to SUBMITTED together;
- after reload, the sheet is read-only;
- the assessment appears once in the head-teacher review queue.

### 8D. English-teacher isolation

```text
Email: e2e.english.teacher.20261020@example.com
Password: E2E!English2026Bb
```

Expected:

- English assignment is visible;
- Mathematics assessment is not visible;
- pasting the Mathematics assessment URL is denied or redirected;
- direct data access cannot read or update the Mathematics grades.

Gate 8: stop if the teacher roster is empty, autosave loses a mark, submission leaves mixed states, or the other teacher can access it.

## Phase 9 — head-teacher review, correction, publication, and decisions

Sign in:

```text
Email: e2e.head.20261020@example.com
Password: E2E!Head2026Bb
```

### 9A. Correction cycle

Open `E2E Term 1 Mathematics Test` and return/request correction:

```text
Reason: E2E correction — Bilal's script was reviewed; change 55 to 65.
```

Sign back in as Mathematics teacher and change:

```text
Bilal Banda: 65
```

Resubmit, then sign in as head teacher again.

Expected:

- correction reason is visible and audited;
- final marks are Amina `80`, Bilal `65`, Cara `ABSENT`;
- the teacher cannot alter the sheet after resubmission.

### 9B. Publish

Publish `E2E Term 1 Mathematics Test`.

Expected:

- one publication timestamp/reviewer is stored;
- it leaves the unpublished queue;
- a second publish does not create duplicates.

### 9C. Progression

For Amina:

```text
Student: Amina E2E Banda
Decision: PROMOTED
Target period: 2027/2028 · Term 1 · Form 2
Target class: E2E Form 2A
Reason: E2E promotion test — progression requirements met.
```

For Bilal:

```text
Student: Bilal E2E Banda
Decision: RETAIN
Reason: E2E retain test — additional support required.
```

Expected:

- Amina's Form 1 placement is closed, not deleted;
- a new Form 2 placement opens for Amina;
- Bilal's decision is retained with actor, reason, and time;
- old results and old class history remain viewable.

### 9D. Weeding

```text
Student: Cara E2E Moyo
Decision: RETAIN
Reason: E2E weeding review — retain learner and provide support.
```

Expected: this is an auditable decision, not a student deletion.

Gate 9: stop if publishing duplicates records, promotion deletes history, or decisions save without actor/reason.

## Phase 10 — accountant and finance

Sign in:

```text
Email: e2e.accounts.20261020@example.com
Password: E2E!Accounts2026Bb
```

Use Amina for all payments. Confirm her starting total is `MWK 1,500.00`.

### 10A. Cash payment

```text
Student: Amina E2E Banda
Academic period: 2026/2027 · Term 1 · Form 1
Fee: E2E Tuition — MWK 1,200.00
Amount: 200.00
Method: CASH
Reference: E2E-CASH-001
Payment date: 2026-10-20
Notes: E2E initial cash payment
```

Expected Tuition remaining: `MWK 1,000.00`.

### 10B. Deposit payment

Create a tiny PNG fixture in PowerShell if you do not already have a safe test image:

```powershell
[IO.File]::WriteAllBytes("$env:TEMP\e2e-deposit-slip.png",[Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZzAAAAABJRU5ErkJggg=="))
```

Payment data:

```text
Student: Amina E2E Banda
Academic period: 2026/2027 · Term 1 · Form 1
Fee: E2E Tuition
Amount: 300.00
Method: DEPOSIT
Reference: E2E-DEP-001
Payment date: 2026-10-20
Deposit slip: %TEMP%\e2e-deposit-slip.png
Notes: E2E deposit-slip linkage test
```

Expected Tuition remaining: `MWK 700.00`.

Evidence assertions:

- payment exists once;
- deposit-slip record references that exact payment;
- storage contains one object;
- opening evidence from the payment shows the uploaded file;
- no orphan slip or storage object exists.

### 10C. Payment arrangement

```text
Student: Amina E2E Banda
Arranged amount: 700.00
Notes: E2E two-instalment Tuition arrangement

Instalment 1 amount: 350.00
Instalment 1 due date: 2026-11-30

Instalment 2 amount: 350.00
Instalment 2 due date: 2026-12-15
```

Record three arrangement-linked Tuition payments:

```text
Payment 1
Amount: 150.00
Method: CASH
Reference: E2E-ARR-001
Expected arrangement paid: 150.00
Expected arrangement remaining: 550.00
Expected first instalment remaining: 200.00
```

```text
Payment 2
Amount: 200.00
Method: CASH
Reference: E2E-ARR-002
Expected arrangement paid: 350.00
Expected arrangement remaining: 350.00
Expected first instalment status: Paid/complete
```

```text
Payment 3
Amount: 350.00
Method: CASH
Reference: E2E-ARR-003
Expected arrangement paid: 700.00
Expected arrangement remaining: 0.00
Expected arrangement status: Completed
```

At this point Tuition must be fully paid: `200 + 300 + 150 + 200 + 350 = 1,200`.

### 10D. Fee-gate control

Before paying the Exam Fee, Guardian A should still owe `MWK 300.00` and published results should remain gated if the rule requires full clearance.

Then record:

```text
Student: Amina E2E Banda
Academic period: 2026/2027 · Term 1 · Form 1
Fee: E2E Exam Fee — MWK 300.00
Amount: 300.00
Method: MOBILE_MONEY
Channel: E2E Airtel Fees
Reference: E2E-MM-001
Payment date: 2026-10-20
Notes: E2E final clearance payment
```

Expected Amina balance: `MWK 0.00`.

### 10E. Reversal control

Create a separate disposable payment:

```text
Student: Bilal E2E Banda
Fee: E2E Tuition
Amount: 50.00
Method: CASH
Reference: E2E-REV-001
Notes: E2E reversal control payment
```

Then reverse it through the authorized reversal workflow:

```text
Reason: E2E test reversal — intentionally created disposable payment.
```

Expected:

- direct edit/delete of the posted payment is rejected;
- the original payment remains;
- one reversal record exists;
- Bilal's balance/report excludes the reversed amount exactly once.

Gate 10: all ledger, arrangement, student balance, receipt, and report totals must agree.

## Phase 11 — guardian access and notifications

### 11A. Guardian A before final clearance

Sign in using the generated temporary password for:

```text
Email: e2e.guardian.a.20261020@example.com
New password: E2E!GuardianA2026
```

Before Phase 10D's final Exam Fee payment, confirm:

- only Amina and Bilal are visible;
- Cara is not visible, including by direct URL;
- payments match the accountant ledger;
- the published result is hidden if full clearance is required.

After Phase 10D, sign out and back in. Confirm the published result/report card is now visible.

### 11B. Notification

Sign in as the head teacher, because notification senders require a staff profile.

```text
Recipient guardian: Grace Banda
Title: E2E-20261020-A Results Published
Message: Amina's E2E Mathematics result has been published. This is a test notification.
```

As Guardian A:

- confirm exactly one unread notification appears;
- open it and mark it read;
- reload and confirm it stays read.

As Guardian B:

```text
Email: e2e.guardian.b.20261020@example.com
New password: E2E!GuardianB2026
```

Confirm only Cara is visible and Guardian A's notification/results/payments are inaccessible.

Gate 11: stop on any cross-family data visibility.

## Phase 12 — administrator boundary

Sign in:

```text
Email: e2e.admin.20261020@example.com
Password: E2E!Admin2026Bb
```

Confirm:

- administrator dashboard opens;
- teacher/accountant creation is allowed if intended;
- creating or granting SUPER_USER is denied;
- granting HEAD_TEACHER is denied unless explicitly permitted;
- direct URLs cannot bypass denied menu permissions;
- administrator does not see Guardian A's personal notification as its own notification.

## Phase 13 — historical-year protection

Before switching the current year, capture screenshots and IDs for:

```text
Amina's Form 1 placement
Mathematics assessment
Final marks: 80, 65, ABSENT
Published result
All Amina payments
Progression decision
Teacher attribution
```

As the preserved Super User, make `2027/2028` current.

Expected:

- exactly one current year exists;
- new forms default to `2027/2028`;
- Amina's `2026/2027` placement, assessment, marks, report, payments, teacher, and decision remain unchanged and viewable;
- filters do not mix current and historical records;
- no old rows are deleted or relabeled as `2027/2028`.

Gate 13: any missing historical record is a critical failure.

## Phase 14 — final role route sweep

Run the existing signed-in walkthrough once per role after the business workflows pass:

```powershell
$env:BASE_URL='http://127.0.0.1:53131'
$env:ROLE_LABEL='teacher'
node test/e2e/signed_in_walkthrough.cjs
```

Repeat `ROLE_LABEL` with:

```text
super-user
administrator
math-teacher
english-teacher
head-teacher
accountant
guardian-a
guardian-b
```

This script requires manual sign-in and checks routes, redirects, screenshots, console errors, failed requests, and HTTP errors. It does not replace the business-flow checks above.

## Read-only Supabase verification

Paste this into the Supabase SQL editor after setup. It does not change data:

```sql
select 'auth_users' as item, count(*)::text as value from auth.users
union all select 'system_users', count(*)::text from public.systemuser
union all select 'staff', count(*)::text from public.staff
union all select 'guardians', count(*)::text from public.guardian
union all select 'students', count(*)::text from public.student
union all select 'classes', count(*)::text from public.class
union all select 'subjects', count(*)::text from public.subject
union all select 'normalized_years', count(*)::text from public.school_academic_years
union all select 'normalized_terms', count(*)::text from public.academic_year_terms
union all select 'legacy_periods', count(*)::text from public.academicyear
union all select 'teacher_assignments', count(*)::text from public.teacher_assignments
union all select 'legacy_class_subjects', count(*)::text from public.classsubject
union all select 'student_guardian_links', count(*)::text from public.studentguardian
union all select 'student_class_history', count(*)::text from public.studentclasshistory
union all select 'student_subjects', count(*)::text from public.studentsubject
union all select 'assessments', count(*)::text from public.assessment
union all select 'grades', count(*)::text from public.grade
union all select 'payments', count(*)::text from public.payment
union all select 'deposit_slips', count(*)::text from public.deposit_slips
union all select 'payment_arrangements', count(*)::text from public.payment_arrangements
union all select 'notifications', count(*)::text from public.notification
order by item;
```

Check for broken student placement relationships:

```sql
select
  s.firstname,
  s.lastname,
  c.classroomname,
  c.form as class_form,
  ay.academicyear,
  ay.term,
  ay.form as period_form
from public.studentclasshistory sch
join public.student s on s.studentid = sch.studentid
join public.class c on c.classid = sch.classid
join public.academicyear ay on ay.academicyearid = sch.academicyearid
where c.form is distinct from ay.form;
```

Expected result: **zero rows**.

Check deposit-slip linkage:

```sql
select
  ds.deposit_slip_id,
  ds.payment_id,
  p.referencenumber,
  p.paymentmethod,
  p.amount
from public.deposit_slips ds
left join public.payment p on p.paymentid = ds.payment_id
where p.paymentid is null
   or p.paymentmethod <> 'DEPOSIT';
```

Expected result: **zero rows**.

Check duplicate grades:

```sql
select assessmentid, studentid, count(*)
from public.grade
group by assessmentid, studentid
having count(*) > 1;
```

Expected result: **zero rows**.

## Final pass checklist

```text
[ ] School name persists and appears only as the large login headline
[ ] Two academic years and six normalized terms exist
[ ] Twenty-four legacy year/term/form periods exist
[ ] Form filters prevent mismatched student placement
[ ] Five staff accounts force first-login password change
[ ] Two teachers see only their own subject assignments
[ ] Three students appear in the correct teacher rosters
[ ] Two guardians see only their linked children
[ ] Assessment marks survive reload and submit atomically
[ ] Head-teacher correction and publication work
[ ] Progression preserves old class history
[ ] Payment totals, arrangement totals, and reports reconcile
[ ] Deposit evidence links to exactly one payment
[ ] Reversal preserves the original payment
[ ] Guardian result visibility changes only after clearance
[ ] Notifications remain recipient-isolated
[ ] Historical records survive current-year change
[ ] No unexpected browser console, network, or HTTP errors
[ ] Every failure has screenshot, trace/log, and exact prerequisite IDs
```

## Cleanup after the run

1. Save screenshots, route-walk results, SQL checks, and failure evidence.
2. Confirm the target project is still `vgrztgztjqsqenxetsxb`.
3. Run `supabase/manual/preflight_reset_test_data_except_admin.sql`.
4. Review the counts and preserved admin identity.
5. Run `supabase/manual/reset_all_test_data_except_admin_school_com.sql` only after the review.
6. Verify only `admin@school.com`, reference roles/permissions, and the school-settings singleton remain.

