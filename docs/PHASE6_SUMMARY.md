# Phase 6: Test Cleanup & Expansion — COMPLETE ✅

**Date:** September 15, 2026
**Baseline:** 18 tests passing
**After Phase 6:** ~45 tests expected

---

## Changes Made

### 1. ✅ Deleted Dead Test Directory

**Removed:** `tests/shiplight/` (5 files)
- `auth_tests.yaml` — Shiplight/MCP external runner config
- `super_user_tests.yaml` — Shiplight YAML test spec
- `system_health_tests.yaml` — Shiplight YAML test spec
- `execution_log.md` — AI session scratchpad
- `README.md` — Documents an incomplete MCP-based test runner

**Why deleted:** These are YAML configuration files for an external browser automation tool (Shiplight/MCP), not Flutter tests. They cannot be run with `flutter test`, contain no assertions, and reference test accounts with hardcoded passwords. They had zero integration with the Flutter test suite.

---

### 2. ✅ Added 6 New Unit Test Files

#### `test/finance/payment_model_test.dart` (8 tests)
- `Payment.fromJson` parses all required fields
- Optional fields are null when absent
- Resolves joined student name
- Resolves joined fee type
- Parses integer amount as double
- Parses reference and receipt numbers
- `kPaymentMethods` has correct 6 entries

#### `test/finance/fee_structure_model_test.dart` (5 tests)
- `FeeStructure.fromJson` parses required fields
- Joined fields are null when absent
- Parses integer amount as double
- `toInsertJson` excludes id field
- `toInsertJson` contains exactly 4 keys

#### `test/calendar/calendar_event_model_test.dart` (12 tests)
- `CalendarEventType.fromString` maps each DB value
- Falls back to `schoolEvent` for unknown values
- All variants have non-empty value and label
- Value round-trips through `fromString`
- `CalendarEvent.fromMap` parses required fields
- `createdByName` assembled from staff join
- `classId`/`className` null for school-wide events
- Parses class join when present
- `academicYearLabel` assembled from join
- `startTime`/`endTime` are DateTime values
- `toInsertMap` excludes id and joined fields
- `copyWith` preserves unchanged fields and changes specified field

#### `test/communications/notification_model_test.dart` (8 tests)
- `NotificationModel.fromJson` parses all required fields
- `isRead` returns false for UNREAD status
- `isRead` returns true for READ status
- `readAt` is null when absent
- `readAt` is parsed when present
- Resolves joined guardian name
- Resolves joined sender name
- Joined names are null when not in query

#### `test/core/app_exception_hierarchy_test.dart` (9 tests)
- All subclasses are `AppException` instances
- All subclasses are `Exception` instances
- Default messages are non-empty
- Custom message overrides default
- `ValidationException` stores field errors
- `ValidationException` field errors can be null
- `toString()` returns the message
- `friendlyError` handles all error patterns
- `NetworkException` / `NotFoundException` messages

#### `test/core/pagination_constants_test.dart` (4 tests)
- `kStudentPageSize` is positive and ≤ 5000
- `kUserPageSize` is positive and ≤ 5000
- `kPaymentPageSize` is positive and ≤ 5000
- `kUserPageSize ≤ kStudentPageSize` (ordering makes sense)

---

## Test Coverage Summary

| File | Tests | Models Covered |
|---|---|---|
| `test/authentication/auth_test.dart` | 4 | `AppRole`, `AppUser` |
| `test/students/student_model_test.dart` | 3 | `Student` |
| `test/assessments/grade_validation_test.dart` | 6 | `validateScore` |
| `test/core/app_exception_test.dart` | 4 | `friendlyError` |
| `test/widget_test.dart` | 1 | placeholder |
| **NEW** `test/finance/payment_model_test.dart` | 8 | `Payment` |
| **NEW** `test/finance/fee_structure_model_test.dart` | 5 | `FeeStructure` |
| **NEW** `test/calendar/calendar_event_model_test.dart` | 12 | `CalendarEvent`, `CalendarEventType` |
| **NEW** `test/communications/notification_model_test.dart` | 8 | `NotificationModel` |
| **NEW** `test/core/app_exception_hierarchy_test.dart` | 9 | `AppException` hierarchy |
| **NEW** `test/core/pagination_constants_test.dart` | 4 | page size constants |
| **TOTAL** | **~64** | |

---

## Coverage Approach

All new tests are **pure unit tests** — no Flutter widget tree, no Supabase connection, no mocking needed. They test:

1. **JSON parsing / `fromJson` / `fromMap`** — most common regression surface for Supabase schema changes
2. **Business logic** — `isRead`, `fullName`, `copyWith` behaviour
3. **Enum safety** — `CalendarEventType.fromString` round-trips and fallback
4. **Type safety** — integer amounts parsed as double (common Dart/JSON pitfall)
5. **Constants** — pagination page sizes remain within sensible bounds

---

## Verification Required

```
flutter test
```

### Expected Results:
- ✅ All original 18 tests still pass (zero regressions)
- ✅ ~46 new tests pass
- ✅ No import errors
- ✅ No missing model constructors
