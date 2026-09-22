# Regression Checklist

**Purpose:** Verify all critical user workflows still work after each cleanup phase.

**Instructions:** Walk through every section below after each phase. Mark each item with ✅ (pass), ❌ (fail), or ⚠️ (degraded/needs investigation).

**Date Last Verified:** _____________  
**Phase Verified:** Phase ___ of 7  
**Tester:** _____________

---

## Pre-Test Setup

- [ ] Database is seeded with test accounts (run `0015_seed_systemusers.sql` if needed)
- [ ] App builds without errors (`flutter build web --release` or `flutter run`)
- [ ] `flutter analyze` returns 0 errors
- [ ] `flutter test` runs and current pass count recorded: _____ tests passed

---

## Role 1: SUPER_ADMIN

**Test Account:** 
- Email: `superadmin@school.edu` 
- Password: (from seed file)

### Login & Navigation
- [ ] Can log in successfully
- [ ] Redirects to `/super-admin` dashboard after login
- [ ] Dashboard displays correct role name "Super User"
- [ ] Sidebar menu shows all expected navigation items

### Create Action
- [ ] Navigate to User Management
- [ ] Click "Create User" button
- [ ] Fill form with valid data
- [ ] Submit creates user successfully
- [ ] New user appears in list

### Edit Action
- [ ] Select any user from list
- [ ] Click edit/details
- [ ] Modify a field (e.g., change role)
- [ ] Save changes
- [ ] Changes persist and appear in details view

### List View
- [ ] Navigate to User Management list
- [ ] List loads without infinite spinner
- [ ] Can see multiple users
- [ ] Search/filter works (if implemented)
- [ ] Pagination controls work (if implemented)

### Logout
- [ ] Click logout button
- [ ] Returns to login page
- [ ] Cannot access protected routes after logout

---

## Role 2: SYSTEM_ADMIN

**Test Account:**
- Email: `sysadmin@school.edu`
- Password: (from seed file)

### Login & Navigation
- [ ] Can log in successfully
- [ ] Redirects to `/admin` dashboard after login
- [ ] Dashboard displays correct role name "System Admin"
- [ ] Sidebar menu shows appropriate navigation items

### Create Action
- [ ] Navigate to System User Management
- [ ] Click create button
- [ ] Fill form with valid data
- [ ] Submit creates record successfully
- [ ] New record appears in list

### Edit Action
- [ ] Select any system user from list
- [ ] Click edit
- [ ] Modify a field
- [ ] Save changes successfully
- [ ] Changes persist

### List View
- [ ] Navigate to System Users list
- [ ] List loads without errors
- [ ] Can see multiple records
- [ ] No unauthorized data visible

### Logout
- [ ] Logout works
- [ ] Returns to login page

---

## Role 3: ADMINISTRATOR

**Test Account:**
- Email: `administrator@school.edu`
- Password: (from seed file)

### Login & Navigation
- [ ] Can log in successfully
- [ ] Redirects to `/administrator` dashboard after login
- [ ] Dashboard displays correct role name "Administrator"
- [ ] Sidebar menu shows appropriate items

### Create Action
- [ ] Navigate to User Management
- [ ] Click create user button
- [ ] Fill form with valid data
- [ ] Submit creates user successfully
- [ ] New user appears in list

### Edit Action
- [ ] Select a user from list
- [ ] Click edit
- [ ] Modify user details
- [ ] Save changes successfully
- [ ] Changes persist

### List View
- [ ] Navigate to Staff/Guardian list
- [ ] List loads correctly
- [ ] Can view multiple records
- [ ] Filtering works (if available)

### Logout
- [ ] Logout works correctly

---

## Role 4: REGISTRAR

**Test Account:**
- Email: `registrar@school.edu`
- Password: (from seed file)

### Login & Navigation
- [ ] Can log in successfully
- [ ] Redirects to correct dashboard
- [ ] Dashboard displays correct role
- [ ] Sidebar shows registrar-appropriate items

### Create Action
- [ ] Navigate to Students
- [ ] Click "Register Student" button
- [ ] Fill student form with valid data
- [ ] Submit creates student successfully
- [ ] New student appears in list

### Edit Action
- [ ] Select a student from list
- [ ] Click edit
- [ ] Modify student details
- [ ] Save changes successfully
- [ ] Changes persist in database

### List View
- [ ] Navigate to Students list
- [ ] List loads without errors
- [ ] Can see multiple students
- [ ] Status filter works (All/Enrolled/Graduated/Withdrawn)
- [ ] Sort functionality works

### Logout
- [ ] Logout works correctly

---

## Role 5: HEAD_TEACHER

**Test Account:**
- Email: `headteacher@school.edu`
- Password: (from seed file)

### Login & Navigation
- [ ] Can log in successfully
- [ ] Redirects to `/headteacher` dashboard after login
- [ ] Dashboard displays correct role name "Head Teacher"
- [ ] Sidebar shows appropriate navigation items
- [ ] Can access Reports section

### Create Action
- [ ] Navigate to Calendar Events
- [ ] Click "Create Event" button
- [ ] Fill event form with valid data
- [ ] Submit creates event successfully
- [ ] New event appears in calendar

### Edit Action
- [ ] Select an event from calendar/list
- [ ] Click edit
- [ ] Modify event details
- [ ] Save changes successfully
- [ ] Changes persist

### List View
- [ ] Navigate to Reports
- [ ] Financial report loads correctly
- [ ] Enrolment report loads correctly
- [ ] Performance report loads correctly
- [ ] Can select academic year/term
- [ ] Data displays without errors

### Logout
- [ ] Logout works correctly

---

## Role 6: TEACHER

**Test Account:**
- Email: `teacher@school.edu`
- Password: (from seed file)

### Login & Navigation
- [ ] Can log in successfully
- [ ] Redirects to `/teacher` dashboard after login
- [ ] Dashboard displays correct role name "Teacher"
- [ ] Sidebar shows teacher-appropriate items

### Create Action
- [ ] Navigate to Assessments/Grades
- [ ] Select a class and subject
- [ ] Click "Create Assessment" button
- [ ] Fill assessment form
- [ ] Submit creates assessment successfully
- [ ] New assessment appears in list

### Edit Action
- [ ] Navigate to existing assessment
- [ ] Click "Enter Grades" or edit
- [ ] Modify grade for a student
- [ ] Save changes successfully
- [ ] Grade persists in database

### List View
- [ ] Navigate to My Classes
- [ ] Class list loads correctly
- [ ] Can view student list per class
- [ ] Can view existing assessments
- [ ] Student details load correctly

### Logout
- [ ] Logout works correctly

---

## Role 7: ACCOUNTANT

**Test Account:**
- Email: `accountant@school.edu`
- Password: (from seed file)

### Login & Navigation
- [ ] Can log in successfully
- [ ] Redirects to `/accountant` dashboard after login
- [ ] Dashboard displays correct role name "Accountant"
- [ ] Sidebar shows finance-related items

### Create Action
- [ ] Navigate to Record Payment
- [ ] Select a student
- [ ] Fill payment form with valid data
- [ ] Submit records payment successfully
- [ ] Payment appears in transaction history

### Edit Action
- [ ] Navigate to Fee Structures
- [ ] Select existing fee structure
- [ ] Modify amount or details
- [ ] Save changes successfully
- [ ] Changes persist

### List View
- [ ] Navigate to Payments list
- [ ] List loads correctly
- [ ] Can see payment records
- [ ] Can filter by student/date
- [ ] Financial summary displays correctly

### Logout
- [ ] Logout works correctly

---

## Role 8: GUARDIAN

**Test Account:**
- Email: `guardian@school.edu`
- Password: (from seed file)

### Login & Navigation
- [ ] Can log in successfully
- [ ] Redirects to `/guardian` dashboard after login
- [ ] Dashboard displays correct role name "Guardian"
- [ ] Sidebar shows guardian-appropriate items

### View Action (No Create/Edit)
- [ ] Navigate to My Children
- [ ] Linked student(s) display correctly
- [ ] Can view student details
- [ ] Can view academic progress
- [ ] Can view report card (all 3 terms)

### List View
- [ ] Navigate to Notifications
- [ ] Notification list loads correctly
- [ ] Can read notifications
- [ ] Mark as read works
- [ ] Calendar events display correctly

### View Reports
- [ ] Navigate to Report Card
- [ ] Select a child
- [ ] Select academic year
- [ ] Report card displays all terms
- [ ] Subject grades show correctly
- [ ] Percentages and letter grades display

### Logout
- [ ] Logout works correctly

---

## Role 9: GUEST (Unauthenticated)

### Public Access
- [ ] Can access login page at `/`
- [ ] Can access forgot password page
- [ ] Cannot access any protected routes directly
- [ ] Attempting `/admin` redirects to login
- [ ] Attempting `/teacher` redirects to login
- [ ] Attempting `/guardian` redirects to login

### Login Flow
- [ ] Login page renders correctly
- [ ] Email validation works
- [ ] Password field masked
- [ ] "Forgot Password" link visible and works
- [ ] Invalid credentials show error message
- [ ] Valid credentials proceed to role dashboard

---

## Cross-Cutting Concerns

### Route Guards (Test for each role)
- [ ] SUPER_ADMIN cannot access other roles' routes
- [ ] SYSTEM_ADMIN cannot access guardian routes
- [ ] ADMINISTRATOR has appropriate access scope
- [ ] REGISTRAR limited to student management routes
- [ ] HEAD_TEACHER can access reports
- [ ] TEACHER cannot access admin routes
- [ ] ACCOUNTANT limited to finance routes
- [ ] GUARDIAN cannot access staff routes

### Error Handling
- [ ] Network errors show user-friendly message
- [ ] Failed form submissions show validation errors
- [ ] Empty lists show "No records" state
- [ ] Loading states show spinners/skeletons
- [ ] No silent failures (check console logs)

### Performance
- [ ] Pages load in < 3 seconds
- [ ] No infinite loading spinners
- [ ] Large lists don't freeze UI
- [ ] Navigation feels responsive

### Data Integrity
- [ ] Creating record doesn't create duplicates
- [ ] Editing record doesn't corrupt data
- [ ] Deleting record (where allowed) works correctly
- [ ] Relationships maintained (student-guardian, etc.)

---

## Critical Paths (Must Always Work)

### Authentication Flow
- [ ] Login → Dashboard → Logout → Login again works
- [ ] Password reset email triggered successfully
- [ ] Session persists across page refresh
- [ ] Session expires appropriately

### Student Management (REGISTRAR/ADMIN)
- [ ] Register student → appears in list → view details → edit → save → persists

### Grade Entry (TEACHER)
- [ ] Create assessment → enter grades → save → view report → grades visible

### Payment Recording (ACCOUNTANT)
- [ ] Record payment → appears in history → reflected in reports

### Guardian View (GUARDIAN)
- [ ] Login → view children → view grades → view report card → all data visible

---

## Phase-Specific Checks

### After Phase 1 (Cleanup)
- [ ] No `FIX #:` comments visible in code
- [ ] No `print()` statements in production code
- [ ] Proper logging in place

### After Phase 2 (Error Handling)
- [ ] All error states show user-friendly messages
- [ ] No empty catch blocks causing silent failures
- [ ] Retry actions available for failed operations

### After Phase 3 (Model Consolidation)
- [ ] Calendar events display correctly in both features
- [ ] No model conflicts or type errors

### After Phase 4 (RLS Consolidation)
- [ ] All roles still have appropriate data access
- [ ] No role can see unauthorized data
- [ ] Fresh database applies all policies correctly

### After Phase 5 (Pagination)
- [ ] Student list paginates correctly
- [ ] Payment list paginates correctly
- [ ] Audit log paginates correctly
- [ ] "Load More" or page navigation works
- [ ] No duplicate or missing records across pages
- [ ] Financial reports use server-side aggregation
- [ ] Report totals match previous client-side totals

### After Phase 6 (Testing)
- [ ] `flutter test` passes with increased test count
- [ ] `flutter test integration_test/` passes
- [ ] New tests cover pagination and aggregation

### After Phase 7 (Final Pass)
- [ ] `flutter analyze --fatal-infos` passes
- [ ] Code is formatted consistently
- [ ] No leftover TODOs or debug code

---

## Sign-Off

**Phase 0 (Baseline):**
- Date: _______________
- Result: ⬜ PASS / ⬜ FAIL
- Notes: _______________________________________________________

**Phase 1 (Cleanup):**
- Date: _______________
- Result: ⬜ PASS / ⬜ FAIL
- Notes: _______________________________________________________

**Phase 2 (Error Handling):**
- Date: _______________
- Result: ⬜ PASS / ⬜ FAIL
- Notes: _______________________________________________________

**Phase 3 (Model Merge):**
- Date: _______________
- Result: ⬜ PASS / ⬜ FAIL
- Notes: _______________________________________________________

**Phase 4 (RLS):**
- Date: _______________
- Result: ⬜ PASS / ⬜ FAIL
- Notes: _______________________________________________________

**Phase 5 (Pagination):**
- Date: _______________
- Result: ⬜ PASS / ⬜ FAIL
- Notes: _______________________________________________________

**Phase 6 (Testing):**
- Date: _______________
- Result: ⬜ PASS / ⬜ FAIL
- Notes: _______________________________________________________

**Phase 7 (Final):**
- Date: _______________
- Result: ⬜ PASS / ⬜ FAIL
- Notes: _______________________________________________________

---

## Appendix: Known Issues / Expected Failures

Document any known issues that are NOT regressions:
- _______________________________________________________
- _______________________________________________________
- _______________________________________________________
