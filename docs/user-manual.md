# School Management System — User Manual

## Audience and access

This guide covers the confirmed UI for Super Users/Administrators, Head Teachers, Teachers, Accountants, and Guardians. Obtain an account from an authorized administrator. On first sign-in, the app can require a password change. Do not share passwords or payment evidence outside authorized staff.

Launch the configured Flutter application, open **Sign In**, enter the account email and password, and submit. Authentication or profile errors are shown on the page. Use **Forgot Password** if email recovery is configured. Each role is redirected to its own dashboard; opening a disallowed URL returns the user to that dashboard.

## Navigation

Use the dashboard tiles or side menu. Availability depends on role. Common destinations include Students, Academic Structure, Calendar, Notifications, and Reports. Administrative, assessment, finance, and guardian pages appear only where allowed by the current role.

## Administrator tasks

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

## Teacher tasks

### Assessments and grades

1. Open **Assessments & Grades** from the dashboard or menu.
2. Expand an assigned class and subject.
3. Choose **Add Assessment**; enter a name, select Assignment/Test/Exam/End of Term as available, and enter a maximum score greater than zero.
4. Open the assessment and choose **Enter Grades**.
5. Enter a score for each listed enrolled student. Scores cannot exceed the assessment maximum; attendance statuses support pending/present/absent/excused behavior defined by the grade page.
6. Choose **Save Draft Grades**. Draft results do not qualify for progression.
7. Review the roster and choose **Submit Grades**. The app confirms submission; submitted eligible results can be used by progression.

Teachers see only assigned class-subject contexts. An unassigned teacher should see no assignment and database policy rejects direct grade writes.

## Accountant tasks

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

## Head Teacher progression

1. Open **Progression Reviews** and select the school year/form context.
2. Calculate or refresh a student’s annual review.
3. Inspect each term, subject evidence, warnings, annual average, the active pass threshold, and recommendation.
4. If complete, choose **Promote** or **Retain**, enter the required reason, and confirm.

The database calculates evidence from enrolled terms and submitted subject results. Missing eligible results produce `INCOMPLETE` and prevent a decision. Promotion closes the active placement, creates the correctly configured next-form Term 1 placement, enrolls mapped subjects, and writes an audit record. Repeating an already-decided request returns the existing decision rather than duplicating placement. If a next form/class/period mapping is absent, the UI should show the database configuration error.

## Guardian tasks

Guardians use **Payment History**, **Academic Progress**, **Report Card**, Notifications, and Calendar. Data is limited to linked students by RLS. Payment History displays receipt/reference and safe method summaries; it must not reveal full card or bank credentials.

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
