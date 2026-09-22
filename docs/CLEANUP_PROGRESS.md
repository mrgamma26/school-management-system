# School Management App - Cleanup & Scalability Progress

**Goal:** Achieve 8-9/10 code quality, functionality, and scalability with zero regressions.

**Hard Rules:**
1. ❌ No user-visible behavior changes without explicit approval
2. ❌ No RLS permission changes
3. ❌ No schema changes to: student, weedingreview, progressionreview, grade, payment
4. ✅ Run `flutter analyze`, `flutter test`, and regression checklist after every phase
5. ✅ Each phase in its own commit

---

## Phase Status Overview

| Phase | Status | Commit | Date | Notes |
|-------|--------|--------|------|-------|
| Phase 0: Baseline Safety Net | ✅ DOCS READY | - | 2025-01 | Awaiting user verification |
| Phase 1: Debug Cleanup | ⬜ NOT STARTED | - | - | - |
| Phase 2: Error Handling | ⬜ NOT STARTED | - | - | - |
| Phase 3: Model Consolidation | ⬜ NOT STARTED | - | - | - |
| Phase 4: RLS Consolidation | ⬜ NOT STARTED | - | - | - |
| Phase 5: Pagination & Aggregation | ⬜ NOT STARTED | - | - | - |
| Phase 6: Real Tests | ⬜ NOT STARTED | - | - | - |
| Phase 7: Final Pass | ⬜ NOT STARTED | - | - | - |

---

## Phase 0: Baseline Safety Net ✅

### Created Documents
- [x] `docs/regression-checklist.md` - Comprehensive test scenarios for all 9 roles
- [x] `docs/phase0-baseline.md` - Current state recording template
- [x] `docs/PHASE0_SUMMARY.md` - Phase 0 completion guide
- [x] `docs/CLEANUP_PROGRESS.md` - This tracking document

### Pending User Actions
- [ ] Run `flutter analyze` and record output
- [ ] Run `flutter test` and record baseline count
- [ ] Walk regression checklist with current app
- [ ] Document any known issues
- [ ] Confirm ready to proceed

**Blocker:** Waiting for user to verify app builds, tests pass, and regression checklist completes.

---

## Phase 1: Remove Debug Artifacts (Planned)

### Targets
- [ ] Remove all `FIX #:` comments from:
  - `lib/core/router.dart`
  - `lib/core/navigation/nav_items.dart`
  - `lib/features/administration/presentation/pages/user_details_page.dart`
  - `lib/features/administration/presentation/pages/user_management_page.dart`
  - `lib/features/students/presentation/student_list_page.dart`
  - `lib/features/authentication/presentation/pages/forgot_password_page.dart`
  - `lib/features/assessments/presentation/pages/guardian_report_card_page.dart`
  - `lib/features/users/data/repositories/user_repository.dart`

- [ ] Replace `print()` with logging in:
  - `lib/main.dart`
  - `lib/features/communications/data/communications_repository.dart`
  - `lib/features/authentication/presentation/providers/auth_provider.dart`

- [ ] Delete unused file:
  - `lib/app/app_theme.dart` (verify unused first)

- [ ] Fix `pubspec.yaml`:
  - Move `flutter_lints` to `dev_dependencies`

### Success Criteria
- No `FIX \d+:` comments remain
- No `print(` calls in `lib/`
- Consistent logging approach
- `flutter analyze` still clean
- Regression checklist still passes

---

## Phase 2: Fix Silent Errors (Planned)

### Targets
- [ ] Fix empty `catch (_) {}` in:
  - `create_user_page.dart`
  - `staff_form_page.dart`
  - `guardian_form_page.dart`
  - `fee_structure_form_page.dart`
  - `record_payment_page.dart` (2 spots)
  - `student_form_page.dart`

- [ ] Create shared error handler:
  - Add `showErrorSnackBar()` to `core/widgets/app_widgets.dart`
  - Use consistently across all pages

- [ ] Fix `main.dart` Supabase init:
  - Replace silent failure with blocking error screen + retry button

### Success Criteria
- No empty catch blocks remain
- Every async failure shows user-visible error
- Consistent error messaging
- Regression checklist still passes

---

## Phase 3: Model Consolidation (Planned)

### Targets
- [ ] Analyze both CalendarEvent models:
  - `lib/features/calendar/domain/models/calendar_event.dart` (canonical)
  - `lib/features/communications/domain/models/calendar_event.dart` (duplicate)

- [ ] Move canonical version to:
  - `lib/core/models/calendar_event.dart`

- [ ] Update imports in:
  - `calendar_repository.dart`
  - `communications_repository.dart`
  - `notifications_page.dart`
  - `teacher_comment_page.dart`

- [ ] Delete duplicate:
  - `lib/features/communications/domain/models/calendar_event.dart`

### Success Criteria
- Only one CalendarEvent class exists
- Both features compile against shared model
- Calendar events and notifications still display correctly
- Regression checklist still passes

---

## Phase 4: RLS Consolidation (Planned)

### Targets
- [ ] Leave existing migrations untouched (0013, 0016, 0017)
- [ ] Create new migration: `0018_consolidated_baseline.sql`
- [ ] Document migration path in: `supabase/MIGRATIONS.md`
- [ ] Audit final RLS state for all 9 roles
- [ ] Pay special attention to: ACCOUNTANT, REGISTRAR (most patched)

### Success Criteria
- Fresh database reaches correct RLS state in one pass
- All 9 roles have correct access (walk checklist carefully)
- Migration documentation clear
- No data access regressions

---

## Phase 5: Pagination & Server Aggregation (Planned)

### Targets

#### Pagination
- [ ] Add pagination to:
  - `student_repository.dart` (listStudents)
  - `user_repository.dart` (staff/guardian lists)
  - `finance_repository.dart` (payment lists)
  - `audit_log_page.dart` query

- [ ] Add UI controls:
  - "Load More" or page navigation
  - Preserve existing sort/filter behavior
  - Page size: 25-50 records

#### Server-Side Aggregation
- [ ] Move financial aggregation to database:
  - Create RPC functions or views for daily/monthly totals
  - Replace client-side Dart aggregation in `reports_page.dart`
  - Verify numbers match exactly (before/after comparison)

#### Audit Log
- [ ] Cap audit log query with pagination
- [ ] Move filters to server-side (`.eq().ilike()`)

#### Verification
- [ ] Audit all remaining `.select()` calls for missing `.range().limit()`
- [ ] Confirm small tables (role, academicyear) are fine unpaginated

### Success Criteria
- All user-scale tables paginated
- Reports use database aggregation with matching output
- No unbounded queries remain
- Regression checklist passes including pagination test

---

## Phase 6: Real Tests (Planned)

### Targets
- [ ] Delete: `tests/shiplight/` (non-functional e2e suite)

- [ ] Create `integration_test/` with:
  - Login smoke test per role
  - Router guard test per role
  - Pagination test for at least one list

- [ ] Expand unit tests:
  - Weeding decision logic
  - Grade validation edge cases
  - Payment aggregation RPC output

- [ ] Replace `test/widget_test.dart`:
  - Real smoke test pumping login page

### Success Criteria
- `flutter test` and `flutter test integration_test/` both pass
- `tests/shiplight/` deleted
- Test line count meaningfully increased
- Tests cover new Phase 5 features

---

## Phase 7: Final Pass (Planned)

### Targets
- [ ] Run `flutter analyze --fatal-infos` and fix all warnings
- [ ] Run `dart format .` across repo
- [ ] Grep for `TODO`/`FIXME`/debug scaffolding from cleanup itself
- [ ] Walk full regression checklist for all 9 roles
- [ ] Generate final summary report

### Final Summary Must Include
- Files deleted/merged count
- Test code lines added and coverage
- List views now paginated
- Queries now server-aggregated
- RLS gaps found and fixed
- Any behavior flagged instead of silently changed

---

## Success Metrics (8-9/10 Target)

### Code Quality ⬜
- [ ] No debug artifacts
- [ ] No dead/duplicate files
- [ ] One clean migration path for fresh environments
- [ ] Consistent error handling and logging
- [ ] Formatted and analyzed code

### Functionality ⬜
- [ ] Everything works identically (verified via checklist)
- [ ] Failures now visible instead of silent
- [ ] Real tests exist that catch regressions

### Scalability ⬜
- [ ] No unbounded queries
- [ ] Financial aggregation in database
- [ ] Performance doesn't degrade with data growth

---

## Git Commit Strategy

Each phase will be committed separately:

```bash
git add -A
git commit -m "Phase 0: Baseline documentation and regression checklist"
git commit -m "Phase 1: Remove debug artifacts and add logging"
git commit -m "Phase 2: Fix silent error handling"
git commit -m "Phase 3: Consolidate CalendarEvent model"
git commit -m "Phase 4: Consolidate RLS policies"
git commit -m "Phase 5: Add pagination and server-side aggregation"
git commit -m "Phase 6: Replace e2e suite with real integration tests"
git commit -m "Phase 7: Final cleanup and formatting"
```

Each commit includes:
- Code changes for that phase
- Updated `docs/CLEANUP_PROGRESS.md`
- Regression checklist verification notes

---

## Current Blockers

**Phase 0:** ⚠️ Waiting for user to:
1. Run `flutter analyze` and record output
2. Run `flutter test` and record baseline
3. Walk regression checklist with current app
4. Confirm ready to proceed

**Phase 1-7:** ⏸️ Blocked by Phase 0 completion

---

## Notes

- Terminal commands (`flutter analyze`, `flutter test`) timing out in AI environment
- User must run commands manually and provide results
- All documentation created and ready for user verification
- No code has been modified yet (Phase 0 is documentation-only)

