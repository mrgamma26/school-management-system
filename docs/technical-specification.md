# School Management System — Technical Specification

## Purpose and scope

This repository contains a role-based school administration client. It manages users, form-scoped academic periods, classes and subjects, student enrollment, teacher assessments, finance, communications, calendar events, progression, weeding reviews, reports, and audit records. The source of truth for confirmed behavior is the Flutter code under [`lib/`](../lib/) and the PostgreSQL migrations under [`supabase/migrations/`](../supabase/migrations/).

Supported Flutter platform folders are Android, iOS, Linux, macOS, Web, and Windows. The October 2026 live verification used Flutter Web. Platform-specific production readiness outside Web is unknown and needs confirmation.

## Prerequisites and configuration

- Flutter SDK compatible with Dart `^3.12.2`
- A Supabase project with migrations applied in numeric order
- Supabase Edge Functions deployed for user creation, deletion, password reset, and notification email
- Runtime variables `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`

Never commit variable values. The expected local file is `env/dev.json`, which is ignored. Typical commands:

```text
flutter pub get
flutter run --dart-define-from-file=env/dev.json
flutter build web --dart-define-from-file=env/dev.json
flutter analyze
flutter test
```

Application startup is [`lib/main.dart`](../lib/main.dart): Flutter bindings are initialized, semantics can be forced with `E2E_TEST`, Supabase is initialized with a ten-second timeout, then a Riverpod `ProviderScope` hosts `SchoolApp`. Initialization failure is logged and the widget tree starts, but most authenticated features still require Supabase.

## Architecture

The app is feature-oriented:

| Area | Responsibility |
|---|---|
| `lib/app` | Root `MaterialApp.router` and app-layer router export |
| `lib/core` | Authentication helpers, route guards, shared errors, database accessor, audit/export services, and utilities |
| `lib/features/*/domain` | Serializable domain models where a feature defines them |
| `lib/features/*/data` | Supabase repositories; assessment and grade models also currently live here |
| `lib/features/*/presentation` | Riverpod providers, pages, dialogs, dashboards, and forms |
| `lib/theme`, `lib/widgets` | Design tokens and shared UI |
| `supabase/migrations` | PostgreSQL schema, RLS policies, indexes, and trusted RPCs |
| `supabase/functions` | Administrative/email operations requiring server-side privileges |

Flutter widgets call Riverpod providers or repositories, repositories call the global Supabase client, and Supabase applies Auth, RLS, constraints, triggers, and RPC logic. Some pages call Supabase through page-local providers; the layering is therefore pragmatic rather than strict.

### Navigation, state, and authorization

[`lib/core/router.dart`](../lib/core/router.dart) owns GoRouter routes, authentication redirects, password-change enforcement, and role-prefix checks. Auth state is a Riverpod `Notifier` in [`auth_provider.dart`](../lib/features/authentication/presentation/providers/auth_provider.dart). The shell and role menus are in [`lib/widgets/app_shell.dart`](../lib/widgets/app_shell.dart). Role checks in the client improve UX; database RLS and security-definer RPC checks remain the security boundary.

Canonical roles are `SUPER_USER`, `ADMINISTRATOR`, `HEAD_TEACHER`, `TEACHER`, `ACCOUNTANT`, and `GUARDIAN`; `SYSTEM_ADMIN` is normalized to `SUPER_USER`. Unknown role semantics need confirmation if additional role rows are introduced.

State is mostly Riverpod `Provider`, `FutureProvider`, and `NotifierProvider`; forms also use widget-local state. Calendar draft persistence uses SharedPreferences. No local relational database is used.

### Network, persistence, and errors

All primary application data is stored in Supabase PostgreSQL. Supabase Auth supplies sessions; `systemuser.userid` bridges an Auth user to the application role. Repositories use PostgREST queries and RPC calls. Edge Functions handle privileged user lifecycle and email delivery.

Repositories generally map database/PostgREST exceptions to friendly messages through [`app_exception.dart`](../lib/core/errors/app_exception.dart), although several repositories contain similar private mapping code. UI pages show inline errors, snackbars, or shared loading/empty/error widgets.

## Important flows

1. **Sign in:** login form → `AuthNotifier.signIn` → `AuthRepository` → Supabase Auth → `systemuser`/`role` profile → GoRouter role home.
2. **Student registration:** form → `StudentRepository` and user/guardian operations → student, guardian/link, class placement, and subject enrollment rows.
3. **Assessment:** teacher assignment → assessment insert → enrolled student roster → grade upserts as `DRAFT` → assessment submission changes eligible grades to `SUBMITTED`.
4. **Payment:** accountant selects student/fee/method → method-specific validation → `record_payment_v2` RPC → payment and audit rows → account and guardian histories.
5. **Progression:** Head Teacher requests annual evidence → trusted calculation RPC evaluates enrolled terms and submitted subject results → complete review can be decided → placement and student-subject rows are updated atomically.

See [`docs/architecture/`](architecture/) for editable diagrams.

## Model catalog

| Model/state | Kind | Important fields and relationships | Main source/use |
|---|---|---|---|
| `AppRole` | Domain/DTO | role id, name, description | Authentication/admin role UI |
| `AppUser` | Domain/DTO | user id, username, role id/name, password-change and active flags | Authentication state and routing |
| `AuthState` | UI state | loading, current user, error | Global auth provider |
| `AcademicYear` | Domain/DTO | id, year, term, form, start/end | Form-scoped academic period UI |
| `ClassModel` | Domain/DTO | class id/name/form | Classes, placement, assignment |
| `Subject` | Domain/DTO | id, name, description | Subject maintenance |
| `ClassSubject` | Joined DTO | assignment id and class/subject/staff/period labels | Teacher assignments and assessment context |
| `Student` | Domain/DTO | identity, gender, birth date, address, enrollment status | Student pages; currently also loads status values via Supabase |
| `Staff` | Domain/DTO | staff/user ids, employee number, names, gender, email | User/staff and assignment UI |
| `Guardian` | Domain/DTO | guardian/user ids, names, contact fields | Guardian management and student links |
| `Assessment` | Data-layer DTO | id, class-subject id, name, type, max score | Assessment repository/pages |
| `Grade` | Data-layer DTO | id, assessment/student/teacher ids, score, attendance status | Grade entry; database submission status is not exposed by this model |
| `FeeStructure` | Domain/DTO | fee id, academic period, fee type, amount/year label | Fee maintenance/account balances |
| `Payment` | Domain/DTO | payment/student/fee/recorder ids, amount/date/method, reference/receipt, channel summary, fee | Account and guardian payment histories |
| `PaymentChannel` | Domain/DTO | id, type, display/provider/masked identifier, currency, active | Admin payment configuration and dynamic payment form |
| `FinancialAdjustment` | Domain/DTO | student/approver, signed amount, reason/date | Discounts, waivers, penalties |
| `NotificationModel` | Domain/DTO | guardian/sender, subject/message, email/read states and timestamps | Notifications |
| `TeacherComment` | Domain/DTO | student/staff/period, comment and joined labels | Student comments/reporting |
| `CalendarEvent` | Domain/DTO | class/creator/period, type, description, start/end/all-day | Calendar pages; `CalendarEventType` has school, academic, sports, meeting, holiday |
| `TileData`, `NavItem`, `MenuNode` | View/navigation models | display labels, icons, paths, nesting | Dashboards and app shell |

Sources: feature model files under [`lib/features`](../lib/features/), assessment repositories, and [`lib/core/router.dart`](../lib/core/router.dart). Map-shaped progression/weeding/audit/report results have no typed model; their stable contract is unknown and should be typed before public reuse.

## Persisted data dictionary

This is the final intended schema reconstructed from migrations `0001`–`0044`, not a live database introspection. `PK`/`FK` identify keys; unmarked fields are nullable where the migration permits it. Common `createdat`/`updatedat` fields are `timestamptz`, required, default `now()` unless noted.

| Entity | Confirmed fields and constraints | Relationships/meaning |
|---|---|---|
| `role` | `roleid uuid PK default gen_random_uuid()`, `rolename text required unique`, `description text`, timestamps | Application roles |
| `rolepermission` | `permissionid uuid PK`, `roleid uuid FK required`, `permissionname text required`, `createdat` | Permissions per role; migration `0030` reconciles legacy variants |
| `systemuser` | `userid uuid PK`, `roleid FK required`, `username text required unique`, `mustchangepassword bool default true`, `isactive bool default true`, timestamps | One-to-one bridge to Supabase Auth user id |
| `staff` | `staffid uuid PK`, `userid FK required unique`, `employeenumber/email unique`, names/gender required, middle name optional, timestamps | Staff profile for application users |
| `guardian` | `guardianid uuid PK`, `userid FK unique`, names/gender/email required, phone/address optional, timestamps | Guardian profile; nullability of legacy `userid` needs live-schema confirmation |
| `auditlog` | `auditid uuid PK`, `userid FK`, `recordid`, `actorrole`, `action/tablename required`, old/new `jsonb`, reason, `createdat` | Security/business audit. Later compatibility migrations use `actorrole`; deployed `recordid` type has varied between text and uuid |
| `academicyear` | `academicyearid uuid PK`, `academicyear int`, `term term_type`, `termname text` compatibility field, `form` checked Form 1–4, start/end dates, timestamps, unique `(academicyear,term,form)` | A form-scoped term; different forms may have different dates in the same school year |
| `class` | `classid uuid PK`, `classroomname text unique`, `form` (renamed from legacy `formlevel`), timestamps | A class such as Form 1A |
| `subject` | `subjectid uuid PK`, `subjectname text unique`, description, timestamps | Subject catalog |
| `classsubject` | `classsubjectid uuid PK`, class/subject/staff/academic-year FKs required, timestamps, unique class+subject+period | A teacher assignment |
| `student` | `studentid uuid PK`, names/gender/birth date required, address, enrollment status enum, timestamps | Learner profile |
| `studentguardian` | `studentguardianid uuid PK`, student/guardian FKs required, relationship required, `createdat`, unique student+guardian | Many-to-many guardian link |
| `studentclasshistory` | `historyid uuid PK`, student/class/period FKs, enrollment date required, end date, timestamps; unique active placement index by student+period | Enrollment/placement history |
| `studentsubject` | `studentsubjectid uuid PK`, student/class-subject FKs required, `createdat`, unique pair | Explicit subject enrollment used by grade security |
| `assessment` | `assessmentid uuid PK`, class-subject FK required, name/type/max score required, max score > 0, timestamps | Teacher assessment; `END_OF_TERM` is added by migration `0037` |
| `grade` | `gradeid uuid PK`, assessment/student/entered-by FKs required, score nullable, attendance status default `PENDING`, submission status default `DRAFT`, timestamps, unique assessment+student | Score and separate draft/submitted state |
| `progressionreview` | `reviewid uuid PK`, student/period FKs, average, decision checked pending/promoted/retained, approver FK, school year, reason/date, calculation `jsonb`, target period/class FKs, timestamps; unique annual review index | Trusted annual progression evidence and decision |
| `progressionrule` | `ruleid uuid PK`, pass percentage 0–100 default 50, version default `v1`, active default true, `createdat` | Versioned promotion threshold |
| `weedingreview` | `weedingid uuid PK`, student/period FKs, cumulative average, decision, reason, flag/decision dates, decider FK, timestamps | Student weeding review |
| `feestructure` | `feestructureid uuid PK`, optional class FK after migration `0035`, period FK, fee type, nonnegative amount, timestamps | School-wide or class fee. Legacy unique constraint behavior needs live confirmation when class is null |
| `paymentchannel` | `channelid uuid PK`, checked type, display/provider/masked identifier, currency default MWK, metadata `jsonb`, active flag, creator FK, timestamps, unique type+display name | Admin-configured bank, POS/gateway, or mobile wallet destination |
| `payment` | `paymentid uuid PK`, student/fee/recorder FKs, positive amount, date, checked text method, reference, unique receipt, optional channel FK, transaction details `jsonb`, nonnegative processing fee, timestamps | Audited receipt/payment evidence; unique method+channel+normalized reference index |
| `financialadjustment` | `adjustmentid uuid PK`, student/approver FKs, signed amount, reason, timestamps | Discount/waiver (negative) or penalty (positive) |
| `notification` | `notificationid uuid PK`, guardian/sender FKs, subject/message, email/read enums, sent/read times, timestamps | Staff-to-guardian message |
| `teachercomment` | `commentid uuid PK`, student/staff/period FKs, comment, timestamps, unique student+staff+period | Term narrative comment |
| `calendarevent` | `eventid uuid PK`, optional class/period FKs, creator FK, name/type/description, start/end with end after start, all-day default false, timestamps | Class or school-wide event |

RLS is enabled across the application tables. Critical database enforcement includes teacher-assignment checks for grade writes, Head-Teacher-only progression decisions, guardian-linked reads, and admin-only payment-channel changes. Review migrations [`0032`](../supabase/migrations/0032_teacher_assigned_students_only.sql), [`0040`](../supabase/migrations/0040_progression_and_grade_security.sql), and [`0042`](../supabase/migrations/0042_configurable_payment_channels.sql).

## External dependencies

- Supabase Flutter: Auth, PostgREST, RPC, Edge Functions
- Riverpod: dependency injection and state
- GoRouter: navigation and redirect guards
- `pdf`, `printing`, and `csv`: reports/export
- `shared_preferences`: local form draft persistence
- `path_provider`: platform file paths

## Confirmed issues and prioritized refactor plan

1. **Schema drift risk:** baseline and compatibility migrations represent multiple live schema generations (`auditlog.recordid`, guardian user linkage, legacy period fields). Add an automated clean-database migration test and live schema assertion before deployment.
2. **Data integrity:** progression evidence is date-sensitive. The live test student had an enrollment date outside the attached term, so Terms 1–2 correctly displayed “Not enrolled” and no annual review was created. Add administrative validation preventing mismatched placement dates.
3. **Type gaps:** progression, weeding, audit, and some reports use untyped maps; `Grade` omits submission status. Introduce DTOs incrementally with repository tests.
4. **Mixed responsibilities:** large calendar, student registration, reports, and router files combine querying, validation, and UI. Extract small tested controllers/components without changing routes.
5. **Repeated error mapping:** consolidate repository exception translation only after behavior-parity tests cover existing messages.
6. **Period labels:** `AcademicYear.label` is year-only, so same-year term/form choices may be ambiguous in some finance controls. Use a full label where selection context requires it.

## Build, test, and CI notes

Tests live under [`test/`](../test/) and cover authentication, role access, models, calendar behavior, student registration, assessments, and dashboard widgets. No checked-in CI workflow was found. Supabase migration/RLS integration tests are not automated in the repository. Live-test evidence and limitations are summarized in the user manual below; production credentials and live data are intentionally excluded.
