# School Management System — User Manual

## Audience and access

This guide covers the confirmed UI for Super Users/Administrators, Head Teachers, Teachers, Accountants, and Guardians. Obtain an account from an authorized administrator. On first sign-in, the app can require a password change. Do not share passwords or payment evidence outside authorized staff.

Launch the configured Flutter application, open **Sign In**, enter the account email and password, and submit. Authentication or profile errors are shown on the page. Use **Forgot Password** if email recovery is configured. Each role is redirected to its own dashboard; opening a disallowed URL returns the user to that dashboard.

## Navigation

Use the dashboard tiles or side menu. Availability depends on role. Common destinations include Students, Academic Structure, Calendar, Notifications, and Reports. Administrative, assessment, finance, and guardian pages appear only where allowed by the current role.

## End-to-end operating sequence

The roles must work in dependency order. A later step cannot produce a valid result until the earlier role has created and confirmed its records.

| Order | Role | Outcome owned by the role | Must already exist | Enables |
|---:|---|---|---|---|
| 1 | Super User | Active user accounts, correct roles, and permissions | Supabase project and initial privileged account | Every role can sign in and reach the correct dashboard |
| 2 | Administrator | Academic periods, classes, subjects, assignments, students, guardians, placements, and subject enrollment | Required staff accounts | Teachers receive rosters; finance and progression have valid students and periods |
| 3A | Teacher | Assessments and submitted grades for every assigned enrolled subject | Teacher assignment, student placement, and student-subject enrollment | Head Teacher receives eligible academic evidence |
| 3B | Administrator and Accountant | Payment channels, fee structures, student charges, payments, and adjustments | Academic periods and enrolled students | Account balances and guardian payment history |
| 4 | Head Teacher | Reviewed annual evidence and an audited promotion or retention decision | Submitted required grades and configured next-form Term 1 destination | New placement and guardian progression status |
| 5 | Guardian | Independent confirmation of linked-student payments, progress, report card, notifications, and progression result | Guardian link and records produced by staff | Family visibility and follow-up with the school |

Calendar events, notifications, teacher comments, audit review, and reports operate alongside this sequence throughout the school year.

### Required handoffs

1. The Super User gives staff an active account and the correct role. A dashboard appearing after sign-in is the first confirmation.
2. The Administrator creates the form-specific period before assigning a class, teacher, student, fee, assessment context, or progression destination to it.
3. The Administrator enrolls the student in a class and its assigned subjects. Merely creating a student record is not enough for grade entry.
4. The Accountant may record payments after the student, academic period, fee structure, and receiving channel exist. Finance does not depend on grades.
5. The Teacher may create assessments only for assigned class-subject-period contexts. Draft grades remain work in progress; submitted grades become progression evidence.
6. The Head Teacher may decide progression only when the calculation reports complete evidence. Promotion additionally requires the next form’s Term 1 period, class, and subject assignments.
7. The Guardian sees only students linked to their guardian profile and consumes the results created by the earlier roles.

## Role outcomes and procedures

### 1. Super User — establish controlled access

**Goal:** create active accounts, assign the correct role, and confirm that every user reaches only the intended dashboard.

**Prerequisite:** the initial privileged account and Supabase user-management functions are deployed.

1. Sign in and open **User Management**.
2. Choose **Create User**, enter the staff or guardian identity fields, and select the required role.
3. Save the user and securely deliver the temporary password shown by the application.
4. Have the user sign in and complete the required password change, if prompted.
5. Confirm the user lands on the correct dashboard.
6. Use role permissions and user details to correct access or deactivate an account when necessary.

**Success evidence:** the user is active, the role is correct, password-change status is complete, and restricted routes redirect the user to their own dashboard.

**Next handoff:** Administrator receives active staff accounts for teacher assignment and school setup.

## Administrator tasks

### 2. Administrator — build the school operating structure

**Goal:** create a consistent academic structure and complete enrollment records that other roles can use.

**Prerequisite:** Teacher, Head Teacher, and Accountant accounts exist and can sign in.

### Users and permissions

1. Open **User Management** and choose **Create User**.
2. Select a supported role and enter the displayed profile fields.
3. Save and securely copy the temporary password if the success dialog provides one.
4. Use a user’s detail page for role/status/password operations available to your account.

Validation and server errors remain on the page or appear as a message. User creation uses a privileged Supabase function; if it is unavailable, contact the deployment owner rather than repeatedly creating accounts.

### Form-scoped academic periods

1. Open **Academic Structure → Academic Years**.
2. Add the school year, term, form, start date, and end date.
3. Save. The same school year and term may exist for Forms 1–4 with different dates; the same year+term+form combination must be unique.

Choose dates that contain the students’ enrollment dates. A student linked to a period but enrolled outside its dates will be treated as not enrolled for progression evidence.

### Classes, subjects, and teacher assignments

Create classes and subjects from their respective Academic Structure pages. Under **Class Assignments**, select a period, class, subject, and teacher, then choose **Assign**. The teacher selector is intended to contain staff whose user role is Teacher. Duplicate class/subject/period assignments are rejected.

### Students and guardians

1. Open **Students → Register Student**.
2. Enter the student’s identity, contact, enrollment, period/class, and subject information shown by the form.
3. Add or select guardian details where required.
4. Save and verify the student detail, guardian link, class history, and subjects.

Earlier terms for a genuine late admission should appear as **— / Not enrolled** in progression evidence.

### Payment receiving channels

Open **Finance → Payment Configuration**. Administrators can create or activate/deactivate:

- bank accounts: display name, bank/provider, masked account identifier, currency;
- card gateways/POS terminals: display name, provider, masked terminal identifier, currency;
- mobile wallets/tills: display name, Airtel Money or TNM Mpamba provider, masked wallet identifier, currency.

Never enter full card numbers or unmasked bank credentials.

**Administrator success evidence:** each period shows its form and dates; classes and subjects exist; every class-subject-period assignment has a Teacher; each student has the correct placement, subjects, and guardian link; active receiving channels are available to the Accountant.

**Next handoff:** Teachers receive assigned rosters, the Accountant receives valid students and payment configuration, and the Head Teacher receives a future progression destination.

## Teacher tasks

### 3A. Teacher — produce submitted academic evidence

**Goal:** assess every enrolled learner for every assigned subject and submit complete, valid results.

**Prerequisite:** the Administrator has created the period, assigned the Teacher to a class and subject, placed students in that class, and enrolled them in the assignment’s subject.

### Assessments and grades

1. Open **Assessments & Grades** from the dashboard or menu.
2. Expand an assigned class and subject.
3. Choose **Add Assessment**; enter a name, select Assignment/Test/Exam/End of Term as available, and enter a maximum score greater than zero.
4. Open the assessment and choose **Enter Grades**.
5. Enter a score for each listed enrolled student. Scores cannot exceed the assessment maximum; attendance statuses support pending/present/absent/excused behavior defined by the grade page.
6. Choose **Save Draft Grades**. Draft results do not qualify for progression.
7. Review the roster and choose **Submit Grades**. The app confirms submission; submitted eligible results can be used by progression.

Teachers see only assigned class-subject contexts. An unassigned teacher should see no assignment and database policy rejects direct grade writes.

**Success evidence:** the assessment displays the expected roster, every required score or attendance status is valid, draft saving succeeds, and final submission is confirmed.

**Next handoff:** submitted results become eligible for the Head Teacher’s annual progression calculation. Draft or missing results intentionally block a decision.

## Accountant tasks

### 3B. Accountant — establish and reconcile student finance

**Goal:** create the school’s charges, record auditable payments, and keep student and guardian histories consistent.

**Prerequisite:** academic periods, enrolled students, and any required Administrator-configured receiving channels exist.

### Fee structures and student accounts

Create fees under **Fee Structures**, choosing the academic period, optional class scope exposed by the form, fee name, and nonnegative amount. Open **Students & Accounts**, select a student, then inspect charges, payments, adjustments, and outstanding balance.

### Record a payment

Choose **Record Payment**, select a fee, enter a positive amount and a non-future payment date, then select a method:

- **Cash:** no receiving channel.
- **Bank Transfer:** receiving business account, payer bank, UTR/reference, clearance date, and optional processing fee.
- **Cheque:** six-digit cheque number, drawee bank/branch, cheque and deposit dates, clearance status, and optional deposit-slip reference.
- **Card:** configured gateway/POS, card network, last four digits only, approval code, and optional processing fee.
- **Mobile Money:** configured merchant wallet, SMS/reference code, sender phone, and exact transaction timestamp.
- **Other:** description and external reference.

Save once. The server generates a receipt number and rejects duplicate transaction references for the same method/channel. Verify the entry under **All Payments** and the student account. Accountants cannot configure receiving channels.

**Success evidence:** the payment has a generated receipt, appears in **All Payments**, appears in the student account, affects the balance, and appears in the linked guardian’s Payment History.

**Next handoff:** Guardians can verify payment history; administrators and accountants can use financial reports. This workflow can run before, during, or after teacher assessment work.

## Head Teacher progression

### 4. Head Teacher — decide progression from trusted evidence

**Goal:** review system-calculated annual evidence and record an accountable promotion or retention decision.

**Prerequisite:** the Administrator has configured all applicable form-scoped terms and the next-form Term 1 destination; Teachers have submitted all required enrolled-subject results.

1. Open **Progression Reviews** and select the school year/form context.
2. Calculate or refresh a student’s annual review.
3. Inspect each term, subject evidence, warnings, annual average, the active pass threshold, and recommendation.
4. If complete, choose **Promote** or **Retain**, enter the required reason, and confirm.

The database calculates evidence from enrolled terms and submitted subject results. Missing eligible results produce `INCOMPLETE` and prevent a decision. Promotion closes the active placement, creates the correctly configured next-form Term 1 placement, enrolls mapped subjects, and writes an audit record. Repeating an already-decided request returns the existing decision rather than duplicating placement. If a next form/class/period mapping is absent, the UI should show the database configuration error.

**Success evidence for promotion:** the review is `PROMOTED`, the reason and approver are recorded, the old placement is closed, the next placement and subjects exist, and the audit history contains the decision.

**Success evidence for retention:** the review is `RETAINED`, the reason and approver are recorded, no next-form placement is created, and the audit history contains the decision.

**Next handoff:** the Guardian sees the progression outcome and the Administrator can manage the learner in the resulting placement.

## Guardian tasks

### 5. Guardian — verify the learner’s school record

**Goal:** view the linked learner’s official financial, academic, communication, and progression information without access to other students.

**Prerequisite:** the Administrator has linked the guardian to the student and earlier staff workflows have produced the relevant records.

Guardians use **Payment History**, **Academic Progress**, **Report Card**, Notifications, and Calendar. Data is limited to linked students by RLS. Payment History displays receipt/reference and safe method summaries; it must not reveal full card or bank credentials.

1. Sign in and confirm that only the linked student is visible.
2. Open **Payment History** and compare amounts, methods, dates, references, and generated receipts with school receipts.
3. Open **Academic Progress** and **Report Card** to review submitted results and teacher comments.
4. Open Notifications and Calendar for school communications and events.
5. After the Head Teacher decides progression, confirm the promotion or retention status.
6. Contact the school when a record is missing or differs from the issued receipt/report; Guardians cannot directly alter official records.

**Success evidence:** only linked-student information is visible, payment and academic records match staff records, and the final progression status is displayed after a decision.

## Recovery and help

- Refresh once after an administrator changes assignments, periods, or channels.
- If a list is empty, confirm the selected period/form and the user’s role/assignment.
- If progression says **Not enrolled**, compare the placement enrollment date with the form-specific term dates.
- If progression is **INCOMPLETE**, submit every required enrolled subject result; do not bypass the review through manual promotion.
- If payment save fails, verify all method-specific evidence, date, amount, active receiving channel, and transaction reference.
- Record the exact visible message and contact the deployment owner for RLS, migration, or Edge Function failures.

## October 2026 live verification status

Confirmed in the visible Web app:

- configured bank, card, and mobile receiving channels;
- recorded and displayed Cash, Bank Transfer, Card, Mobile Money, and Cheque payments;
- guardian Payment History showed five payments and safe summaries;
- accountant was redirected away from payment configuration;
- a teacher saved a Mathematics grade as draft, then submitted it;
- progression showed missing-result warnings and did not create a review while incomplete;
- guardian was redirected away from progression review.

Not completed as a valid end-to-end assertion: promotion, retention, duplicate-promotion protection, missing-next-form handling, and late-admission averages. The test student’s placement dates were inconsistent with the configured term dates and other subject results were intentionally incomplete. Correct test fixtures are required before these scenarios can be claimed as passed.

Screenshots and product-specific policy text (school name, support contact, retention policy beyond the configured threshold, receipt branding) are **Unknown / need owner confirmation**.
