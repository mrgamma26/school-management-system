# E2E Test Results - 2026-09-23

App URL: http://localhost:60212/#/login

## Status

Testing is in progress on the release web app. Test 0 and the first part of Test 1 have been exercised with disposable accounts. Academic setup is currently blocked by repeated HTTP 400 responses and list pages that remain in loading states.

## Completed checks

- Release web app opened successfully on port 60212.
- Bootstrap loader transitioned to the login screen.
- Empty login submission showed `Email is required.` and `Password is required.`.
- Password field is masked and exposes a show-password control.
- Invalid credentials returned `Incorrect email or password.` without a blank screen.
- Login baseline screenshot captured in the test session.
- Super User login with `admin@school.com` succeeded.
- Teacher, Head Teacher, Accountant, and Administrator accounts were provisioned and each completed first-login password setup.
- Teacher, Head Teacher, Accountant, Guardian, and Administrator dashboards loaded after password setup.
- Student registration succeeded after supplying a phone number for a Guardian field presented as optional.
- Student list loaded four existing records; search for `Test Student` returned two matches.
- Guardian link action succeeded after selecting an existing guardian and entering `Parent`.
- Guardian Progress page loaded an empty state without a runtime error.

## Not executed

Academic setup, assessments, payments, progression, comments, permission toggles, full guardian data verification, audit-log completeness, and cleanup remain pending or skipped. Academic Years, Classes, and Subjects each remained in a loading state with HTTP 400 responses.

## Next action

Enter the existing Super User credentials in the browser at the URL above. Do not add the password to source control or this results file. Continue testing from Test 0 after successful login.
