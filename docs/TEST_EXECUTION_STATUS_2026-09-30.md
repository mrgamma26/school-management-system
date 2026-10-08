# Test execution status — 30 September 2026

This is the live release-mode execution record for the supplied test plan.

| Step | Status | Evidence / blocker |
|---|---|---|
| 1. Admin sign-in | Passed | Super User login and dashboard loaded. Assessments is absent from the menu and direct route access redirects home. |
| 2. Academic setup | Partially passed | `2026/2027`, Form 1 A, Form 2 A, Mathematics, and English exist. Creating a further subject returned to the list but it was not visible. |
| 3. Staff accounts | Partially passed | Head Teacher, Math Teacher, and English Teacher exist. Accountant has not been created in this run. |
| 4. First login changes | Blocked | Super User does not have the Reset Password action needed to repeatably control staff test passwords. |
| 5. Teacher assignments | Passed | Form 1 A has Mathematics → Math Teacher and English → English Teacher. |
| 6. Register students | Partially passed | One student with a primary guardian exists and inherited both assigned subjects. Student 2 has not been created. |
| 7. Guardian first login | Blocked | The test password workflow is blocked by the reset-password permission issue. |
| 8. Teacher assessments | Blocked | Requires a known Math Teacher password and a second test student. |
| 9. Grade visibility | Not started | Depends on teacher grades and guardian sign-in. |
| 10. Head Teacher review | Not started | Depends on three-term recorded grades. |
| 11. Promotion and weeding | Not implemented | Existing progression and weeding flows are manual; automatic annual average, promotion, and flagging are absent. |
| 12. Guardian notification | Not implemented | No automatic promotion notification producer exists. |
| 13. Accountant workflow | Blocked | Super User Finance navigation and Add Fee action are missing. |
| 14. Calendar | Failed | Calendar form renders, but submitting a school-wide event made the page blank. |
| 15. Final access checks | Partially passed | Admin assessment restriction passed. Remaining roles depend on first-login and test data blockers. |
