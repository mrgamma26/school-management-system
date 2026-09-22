# School Management App — Testing Guide

This document provides a comprehensive module-by-module testing checklist. Test each section thoroughly before marking features as complete.

---

## 🔐 1. Authentication Module

### Login Flow
- [ ] Launch app and see login screen
- [ ] Enter valid email and password → app logs in and navigates to dashboard
- [ ] Enter invalid password → error message "Invalid credentials" appears
- [ ] Enter unregistered email → error message "User not found" appears
- [ ] Password field shows dots/masked text (no plaintext)
- [ ] "Forgot Password" button navigates to password reset screen

### Password Reset
- [ ] Enter registered email → email sent confirmation
- [ ] Open password reset link from email (or simulated)
- [ ] Enter new password (min 8 chars) → password updated
- [ ] Old password no longer works
- [ ] Reset token expires after 1 hour (test if possible)

### Session & Token Handling
- [ ] After login, stay authenticated for 15 minutes (access token TTL)
- [ ] Close app and reopen → session restored via refresh token
- [ ] App automatically refreshes token before expiry (no logout)
- [ ] Logout clears session and navigates to login screen
- [ ] After logout, cannot access authenticated pages (403 forbidden)

### OTP (Multi-Factor Auth) — Admin/Manager Only
- [ ] Admin/Manager login triggers OTP prompt (TOTP app or SMS)
- [ ] Enter correct OTP → login succeeds
- [ ] Enter incorrect OTP → "Invalid code" error, can retry
- [ ] After 5 failed OTP attempts → account locked for 15 minutes
- [ ] Backup codes work as alternative OTP method

---

## 👥 2. User Management (Admin Only)

### Create User
- [ ] Navigate to Users → Create New User
- [ ] Fill form: email, role (Staff/Guardian/Accountant), password
- [ ] Email must be unique (reject duplicate)
- [ ] Password validates: min 12 chars, uppercase, lowercase, digit, special char
- [ ] Click Save → user created and appears in list
- [ ] Email sent to new user with credentials (or password reset link)

### View User List
- [ ] Admin sees all users with role badges
- [ ] List shows: email, role, status (active/inactive), created date
- [ ] Can sort by email, role, date
- [ ] Can search by email or name
- [ ] Pagination works (if >10 users)

### Edit User
- [ ] Click user → edit form opens
- [ ] Can change role (e.g., Staff → Manager) — action logged
- [ ] Can deactivate/reactivate user
- [ ] Cannot edit own email (prevent lockout)
- [ ] Save changes → user updated immediately

### Delete User
- [ ] Click Delete User → confirmation dialog
- [ ] Confirm deletion → user marked as inactive (soft delete)
- [ ] Deleted user cannot log in
- [ ] Deleted user's data is preserved (GDPR compliance)

### Reset User Password
- [ ] Admin can trigger password reset for any user
- [ ] Reset link emailed to user
- [ ] User sets new password via link
- [ ] Admin receives confirmation that password was reset

---

## 🎓 3. Student Management (Admin/Registrar)

### Enroll Student
- [ ] Navigate to Students → Enroll New Student
- [ ] Fill form: first name, middle name (optional), last name, gender, DOB, physical address
- [ ] **Verify enrollment status is saved as lowercase** (critical fix applied)
- [ ] Click Enroll → student appears in list with unique ID
- [ ] Success message shows student ID

### View Student List
- [ ] Registrar/Admin sees all enrolled students
- [ ] List shows: ID, full name, gender, DOB, enrollment status, actions
- [ ] Can filter by status: active, suspended, graduated
- [ ] Can search by name or student ID
- [ ] Can sort by enrollment date, name

### Edit Student
- [ ] Click student → edit form opens
- [ ] Can update name, gender, DOB, address
- [ ] Can change enrollment status (active → suspended, etc.)
- [ ] Save changes → student record updated
- [ ] **Verify enrollment status remains lowercase after edit**

### Link Guardian to Student
- [ ] On student detail page, click "Assign Guardian"
- [ ] Select guardian from dropdown (or create new guardian)
- [ ] Verify link is bidirectional (guardian sees student in their account)
- [ ] Can unlink guardian
- [ ] Student can have multiple guardians

### Student Dashboard (Student/Guardian View)
- [ ] Student logs in → sees their profile and current courses
- [ ] Can view enrolled classes, grades, attendance
- [ ] Guardian sees linked students and their progress
- [ ] Cannot see other students' data (data isolation enforced)

---

## 💳 4. Finance Module (Accountant)

### Fee Structure
- [ ] Navigate to Finance → Fee Structure
- [ ] Create fee structure: amount, description, due date, academic year
- [ ] Fee applies to selected students/classes
- [ ] Can edit or delete fee structures
- [ ] Multiple fee structures can coexist (tuition, uniform, transport, etc.)

### Record Payment
- [ ] Accountant navigates to Payments → Record New Payment
- [ ] Select student and outstanding fees
- [ ] Enter payment method: cash, bank transfer, mobile money
- [ ] Enter amount and payment date
- [ ] Generate receipt (PDF or printable)
- [ ] Payment recorded in ledger

### Student Balance
- [ ] Admin/Accountant can view student's financial summary:
  - Total fees owed
  - Total paid
  - Balance due
  - Payment history
- [ ] Can generate individual student statement
- [ ] Balance updates automatically when payment is recorded

### Payment History & Reports
- [ ] View payment log with: student name, amount, date, method, reference
- [ ] Generate receipt for individual payment
- [ ] Export payment report (by date range, by student)
- [ ] Can generate class/school financial summary

### Financial Reports
- [ ] Daily collections report
- [ ] Monthly revenue report
- [ ] Outstanding fees report (by student, by class)
- [ ] Year-to-date financial summary

---

## 📚 5. Academic Module (If Implemented)

### Class Management (Admin)
- [ ] Create class: name, academic year, teacher
- [ ] Assign students to class
- [ ] View class roster
- [ ] Can edit or archive class

### Attendance Tracking
- [ ] Teacher navigates to Attendance → select class and date
- [ ] Mark students present/absent/late
- [ ] Save attendance sheet
- [ ] View attendance report by student/class/date range

### Grades & Assessment
- [ ] Teacher enters grades for assignments, exams, tests
- [ ] Grades visible to student/guardian after entry
- [ ] Can compute GPA (if applicable)
- [ ] Generate report card

---

## 🔔 6. Notifications & Alerts

### Email Notifications
- [ ] User registration → welcome email sent
- [ ] Password reset → email with reset link
- [ ] Payment recorded → receipt emailed to student/guardian
- [ ] Student enrolled → confirmation to student/guardian
- [ ] Attendance alert → low attendance flag to guardians

### In-App Notifications
- [ ] Real-time notifications show in notification center
- [ ] Can dismiss or archive notifications
- [ ] Unread badge on notification icon

---

## 🛡️ 7. Security & Access Control

### Role-Based Access (RBAC)
- [ ] Admin sees all features and modules
- [ ] Registrar sees only Students module
- [ ] Accountant sees only Finance module
- [ ] Teacher sees only Classes, Attendance, Grades
- [ ] Student sees only own profile/courses/grades
- [ ] Guardian sees linked students' data only

### Cross-Tenant Isolation
- [ ] If multi-school: users from school A cannot see school B data
- [ ] Finance reports show only the current user's school

### Data Validation
- [ ] Cannot submit form with required fields empty
- [ ] Email format validated before submission
- [ ] Phone numbers accept valid formats
- [ ] Dates cannot be in the future (for DOB)
- [ ] Numeric fields reject non-numeric input

### SQL Injection / XSS Prevention
- [ ] Special characters in names (e.g., O'Brien) are saved correctly
- [ ] HTML/script tags in text fields do not execute
- [ ] API rejects malformed requests (400 Bad Request)

---

## 🚀 8. Performance & Load Testing

### Response Times
- [ ] Login completes in < 2 seconds
- [ ] Student list loads in < 1 second (50 students)
- [ ] Dashboard renders in < 1 second
- [ ] Payment recording completes in < 2 seconds

### Concurrent Users
- [ ] App handles multiple concurrent logins without crashes
- [ ] Data consistency maintained (no race conditions)

### Large Dataset Handling
- [ ] App loads 1000+ students without UI lag
- [ ] Search/filter performs efficiently on large lists
- [ ] PDF generation for 500+ payment records completes in < 30s

---

## 📱 9. Mobile UI/UX (Flutter)

### Responsiveness
- [ ] App works on phone (small screen ~6")
- [ ] App works on tablet (large screen ~10")
- [ ] Landscape mode renders correctly
- [ ] No text overflow or layout breaks

### Touch & Interaction
- [ ] All buttons are easily tappable (min 48x48 dp)
- [ ] Forms are mobile-optimized (not cramped)
- [ ] Keyboard appears for text input fields
- [ ] Back button navigates correctly

### Offline Capability (if implemented)
- [ ] App caches recent data for offline viewing
- [ ] Changes sync when connectivity restored
- [ ] Clear offline/online status indicator

---

## ✅ Test Execution Checklist

### Before Each Test Session
- [ ] Clear app cache: Settings → Apps → School Management → Storage → Clear Cache
- [ ] Restart app
- [ ] Ensure internet connection (unless testing offline)
- [ ] Use test data (don't modify production data)

### Bug Reporting
When you find an issue, document:
1. **Steps to reproduce** (exact sequence)
2. **Expected behavior**
3. **Actual behavior**
4. **Device/OS** (Android 12, iOS 16, etc.)
5. **Screenshots or logs** (if applicable)

### Sign-Off
Module is considered **PASS** when all checkboxes in that section are checked.

---

## 📊 Test Results Summary

| Module | Status | Notes | Tester | Date |
|--------|--------|-------|--------|------|
| Authentication | ⚪ Pending | - | - | - |
| User Management | ⚪ Pending | - | - | - |
| Students | ⚪ Pending | Enrollment status fix applied | - | - |
| Finance | ⚪ Pending | - | - | - |
| Academic | ⚪ Pending | - | - | - |
| Notifications | ⚪ Pending | - | - | - |
| Security | ⚪ Pending | - | - | - |
| Performance | ⚪ Pending | - | - | - |
| Mobile UI | ⚪ Pending | - | - | - |

**Legend:** 🟢 PASS | 🟡 PARTIAL | 🔴 FAIL | ⚪ PENDING

---

## Quick Links

- **Bug Tracker:** [Link to issue tracker]
- **API Documentation:** `docs/api.md`
- **Database Schema:** `docs/schema.md`
- **Known Issues:** `docs/known_issues.md`
