# Baseline Status Recorded

**Date:** January 2025  
**Recorded By:** User + AI Assistant

---

## Flutter Analyze Results (Before Fixes)

**Total Issues:** 66
- **Errors:** 4 (build-blocking)
- **Warnings:** 22
- **Info:** 40 (mostly deprecation warnings)

### Build-Blocking Errors (Fixed Immediately)

1. ✅ **FIXED:** `guardian_report_card_page.dart:80` - Wrong return type `Map<int, Map<String, dynamic>>` vs `Map<String, dynamic>`
   - **Fix:** Changed provider return type to `Map<int, Map<String, dynamic>>`

2. ✅ **FIXED:** `user_details_page.dart:145` - Undefined parameter 'metadata' in AuditService.log()
   - **Fix:** Changed to `previousValue` and `newValue` parameters

3. ✅ **FIXED:** `guardian_report_card_page.dart:256` - String can't be assigned to int
   - **Fix:** Added explicit cast `year as int`

4. ✅ **FIXED:** `export_service.dart:416` - `List<List<dynamic>>` can't be assigned to `List<List<String>>`
   - **Fix:** Added `.toString()` calls to ensure String types

**Result:** App now builds successfully!

---

## Remaining Issues (Non-Blocking - Will Fix in Phases)

### Deprecation Warnings (40 items)
- `anonKey` → should use `publishableKey`
- `groupValue`/`onChanged` in Radio widgets → RadioGroup pattern
- `value` in form fields → `initialValue`
- `withOpacity` → `.withValues()`
- Many others from Flutter 3.33+ updates

### Code Quality Warnings (22 items)
- Unused variables: `_yearLabel`, `isWide`, `currentUser`, `repo`, `cls`
- Unnecessary underscores in `router.dart:194`
- Unnecessary null comparison in `staff_list_page.dart:158`
- Unused import: `package:flutter/services.dart` in export_service
- `BuildContext` across async gaps (6 occurrences)
- `.state` misuse in audit_log_page (12 occurrences)

### `print()` Statements (3 items)
- `lib/main.dart` (2 occurrences)
- `lib/features/communications/data/communications_repository.dart` (2 occurrences)

### Style Issues
- Non-lowerCamelCase: `_StatGrid`, `_ActionGrid`, `_SystemGrid` in admin_dashboard

---

## Flutter Test Results

**Status:** ✅ Tests pass  
**Output:** `+18: All tests passed!`

**Test Files:**
1. `test/widget_test.dart` - Placeholder (always passes)
2. `test/students/student_model_test.dart`
3. `test/core/app_exception_test.dart`
4. `test/authentication/auth_test.dart`
5. `test/assessments/grade_validation_test.dart`

**Total Real Tests:** ~18 (exact count from placeholder message)

---

## App Launch Status

**Chrome Build:** ✅ Successful (after fixing 4 errors)
- Login page loads
- No runtime errors during build
- Ready for manual testing

---

## Regression Checklist Status

**Status:** ⏸️ Ready for user to walk through

**Priority Test Paths:**
1. Login with test accounts (all 9 roles)
2. Navigate to home dashboard
3. Perform one CRUD operation per role
4. Logout

**Expected Result:** Everything works as before (zero regressions)

---

## Issues That MUST Be Fixed

### Phase 1 Targets (Debug Cleanup)
- Remove all `FIX #:` comments (8+ files)
- Replace 5 `print()` calls with logging
- Fix unused imports/variables
- Move `flutter_lints` to dev_dependencies

### Phase 2 Targets (Error Handling)
- Fix empty `catch (_) {}` blocks (7+ files)
- Add visible error messages
- Fix Supabase init failure in main.dart

### Phase 3 Targets (Model Consolidation)
- Merge duplicate CalendarEvent classes

### Phase 4 Targets (RLS)
- Consolidate migrations
- Audit all 9 roles for access gaps

### Phase 5 Targets (Scalability)
- Add pagination to all list views
- Move financial aggregation to database
- No unbounded queries

### Phase 6 Targets (Testing)
- Delete `tests/shiplight/`
- Create real integration tests
- Expand unit test coverage

### Phase 7 Targets (Final)
- Fix all deprecation warnings
- Format code
- Final regression check

---

## Next Steps

1. ✅ **DONE:** Fix 4 build-blocking errors
2. ✅ **DONE:** Record baseline metrics
3. ⏸️ **PENDING:** User walks regression checklist (optional but recommended)
4. ▶️ **NEXT:** Proceed to Phase 1 - Debug Cleanup

**Ready to proceed with official Phase 1!**
