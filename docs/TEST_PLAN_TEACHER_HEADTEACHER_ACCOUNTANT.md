# Teacher, Head Teacher, and Accountant test plan

Run the subject-and-teacher setup first. It should provide one class, three
subjects, three teachers, at least one enrolled student, and at least one
guardian linked to that student.

## Shared test data

- Academic year: create one active academic year.
- Class: Form 2 A.
- Subjects: Mathematics, English, Science.
- Teachers: Teacher One, Teacher Two, Teacher Three.
- Assignments: give each subject one teacher in Form 2 A for the active year.
- Student: enrol one student in Form 2 A and add all three subjects.
- Guardian: link one guardian to that student.
- Finance: create one fee structure and one payment for the student.
- Calendar: create one school-wide calendar event as an administrator.

## Teacher

1. Sign in as Teacher One.
2. Open Students. Confirm only students in Teacher One's assigned class and
   academic year are visible. A student in another class must not appear.
3. Open Assessments. Confirm only Teacher One's Mathematics assignment appears.
4. Create a Mathematics assessment and enter a grade for the enrolled student.
5. Confirm the English and Science assignments cannot be opened or edited by
   Teacher One.
6. Open the calendar. Confirm the school-wide event is visible, but there is
   no Add Event, Edit, or Delete option.
7. Confirm User Management, Academic Year setup, Class setup, payments, and
   role permissions are unavailable.

Expected result: the teacher can teach and grade only their assigned
class-subject students, and can view shared school information.

## Head Teacher

1. Sign in as the Head Teacher.
2. Open Students and confirm student records can be viewed.
3. Open Assessments and confirm assessment and grade information can be
   reviewed without changing another teacher's grade.
4. Open Progression Reviews and Weeding Reviews. Create or approve a review
   for the test student where the workflow allows it.
5. Open the calendar. Confirm school events are visible but calendar creation,
   editing, and deletion remain administrator-only.
6. Confirm the Head Teacher cannot create or remove user accounts, change role
   permissions, or record payments.

Expected result: the Head Teacher can supervise academics and reviews without
receiving administrator, teacher-assignment, or finance powers.

## Accountant

1. Sign in as the Accountant.
2. Open Students and search for the test student.
3. Open Fee Structures. Create a test fee for Form 2 A.
4. Open Record Payment. Record a payment for the test student and confirm a
   receipt number is shown.
5. Open All Payments and the student account. Confirm the payment, balance,
   and payment history agree.
6. Open the guardian payment view with the guardian account. Confirm the same
   payment is visible to the linked guardian.
7. Confirm the Accountant cannot create assessments, enter grades, manage
   class-subject assignments, change users, or create calendar events.

Expected result: the Accountant can perform finance work and view the student
information needed for it, without academic or administrator write access.

## Final access check

For each role, sign out and sign back in after testing. Confirm that a page
opened directly by URL still respects the role restriction and does not expose
data or write buttons.
