import 'auth/school_role_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../features/authentication/presentation/pages/login_page.dart';
import '../features/authentication/presentation/pages/change_password_page.dart';
import '../features/authentication/presentation/pages/forgot_password_page.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';
import '../features/dashboards/presentation/role_home.dart';
import '../features/administration/presentation/pages/user_management_page.dart';
import '../features/administration/presentation/pages/create_user_page.dart';
import '../features/administration/presentation/pages/user_details_page.dart';
import '../features/administration/presentation/pages/manage_permissions_page.dart';
import '../features/academics/presentation/pages/academic_year_list_page.dart';
import '../features/academics/presentation/pages/academic_year_form_page.dart';
import '../features/academics/domain/models/academic_year.dart';
import '../features/academics/presentation/pages/class_list_page.dart';
import '../features/academics/presentation/pages/class_form_page.dart';
import '../features/academics/domain/models/class_model.dart';
import '../features/academics/presentation/pages/subject_list_page.dart';
import '../features/academics/presentation/pages/subject_form_page.dart';
import '../features/academics/domain/models/subject.dart';
import '../features/finance/presentation/pages/all_payments_page.dart';
import '../features/finance/presentation/pages/fee_structure_list_page.dart';
import '../features/finance/presentation/pages/fee_structure_form_page.dart';
import '../features/finance/domain/models/fee_structure.dart';
import '../features/finance/presentation/pages/record_payment_page.dart';
import '../features/finance/presentation/pages/student_account_page.dart';
import '../features/finance/presentation/pages/payment_configuration_page.dart';
import '../features/students/presentation/student_list_page.dart';
import '../features/students/presentation/teacher_class_students_page.dart';
import '../features/students/presentation/student_form_page.dart';
import '../features/students/domain/student.dart';
import '../features/students/presentation/student_details_page.dart';
import '../features/students/presentation/guardian_link_page.dart';
import '../features/students/presentation/student_subjects_page.dart';
import '../features/students/presentation/class_history_page.dart';
import '../features/students/presentation/promote_student_page.dart';
import '../features/users/presentation/pages/staff_list_page.dart';
import '../features/users/presentation/pages/staff_form_page.dart';
import '../features/users/domain/models/staff.dart';
import '../features/users/presentation/pages/guardian_list_page.dart';
import '../features/users/presentation/pages/guardian_form_page.dart';
import '../features/users/domain/models/guardian.dart';
import '../features/calendar/presentation/pages/calendar_page.dart';
import '../features/calendar/presentation/pages/calendar_event_form_page.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/assessments/presentation/pages/assessments_page.dart';
import '../features/assessments/presentation/pages/grade_entry_page.dart';
import '../features/assessments/presentation/pages/guardian_academic_progress_page.dart';
import '../features/assessments/presentation/pages/guardian_report_card_page.dart';
import '../features/progression/presentation/pages/progression_reviews_page.dart';
import '../features/weeding/presentation/pages/weeding_reviews_page.dart';
import '../features/academics/presentation/pages/class_assignment_page.dart';
import '../features/communications/presentation/pages/notifications_page.dart';
import '../features/communications/presentation/pages/teacher_comment_page.dart';
import '../features/finance/presentation/pages/guardian_payment_history_page.dart';
import '../features/administration/presentation/pages/audit_log_page.dart';
import '../features/reports/presentation/pages/reports_page.dart';

// ── Role → home route mapping ────────────────────────────────────────────────

String _canonicalRoleName(String role) {
  final normalized = role.trim().toUpperCase();
  return normalized == 'SYSTEM_ADMIN' ? 'SUPER_USER' : normalized;
}

/// Returns the initial route path for a given [role] name (from the database).
String homeForRole(String role) {
  switch (_canonicalRoleName(role)) {
    case 'ADMINISTRATOR':
      return '/administrator/home';
    case 'TEACHER':
      return '/teacher/home';
    case 'HEAD_TEACHER':
      return '/headteacher/home';
    case 'ACCOUNTANT':
      return '/accountant/home';
    case 'GUARDIAN':
      return '/guardian/home';
    case 'SUPER_USER':
    default:
      return '/admin/home';
  }
}

// ── FIX 5: Role-based route access control ───────────────────────────────────

/// Maps each role to the list of route prefixes they are allowed to access.
/// Used by the router redirect logic to enforce role-based access control.
const Map<String, List<String>> _roleRouteAccess = {
  'SUPER_USER': [
    '/admin/',
    '/administrator/',
    '/teacher/',
    '/headteacher/',
    '/accountant/',
    '/guardian/',
    '/students',
    '/users/',
    '/academics/',
    '/finance/',
    '/calendar',
    '/progression/',
    '/weeding/',
    '/notifications',
    '/teacher/comments',
    '/reports',
  ],
  'ADMINISTRATOR': [
    '/administrator/',
    '/students',
    '/users/',
    '/academics/',
    '/finance/',
    '/calendar',
    '/progression/',
    '/weeding/',
    '/notifications',
    '/teacher/comments',
    '/reports',
  ],
  'HEAD_TEACHER': [
    '/headteacher/',
    '/students',
    '/users/',
    '/academics/',
    '/calendar',
    '/progression/',
    '/weeding/',
    '/notifications',
    '/teacher/comments',
    '/reports',
  ],
  'TEACHER': [
    '/teacher/',
    '/students',
    '/academics/',
    '/calendar',
    '/assessments',
    '/notifications',
    '/teacher/comments',
  ],
  'ACCOUNTANT': [
    '/accountant/',
    '/students',
    '/finance/',
    '/calendar',
    '/notifications',
    '/reports',
  ],
  'GUARDIAN': ['/guardian/', '/notifications', '/calendar'],
};

/// Checks if a user with the given [role] is allowed to access the [path].
/// Returns true if allowed, false otherwise.
bool _isRouteAllowedForRole(String role, String path) {
  // Public authentication routes remain reachable before a user profile loads.
  if (path == '/login' ||
      path == '/forgot-password' ||
      path == '/change-password' ||
      path == '/reset-password') {
    return true;
  }

  final normalizedRole = _canonicalRoleName(role);
  if (path == '/finance/payment-configuration' &&
      !const {'SUPER_USER', 'ADMINISTRATOR'}.contains(normalizedRole)) {
    return false;
  }
  if (path.endsWith('/class-history/promote') &&
      !const {
        'SUPER_USER',
        'ADMINISTRATOR',
        'ADMIN',
      }.contains(normalizedRole)) {
    return false;
  }
  if ((path.startsWith('/progression/') || path.startsWith('/weeding/')) &&
      !canAccessSchoolReviews(normalizedRole)) {
    return false;
  }
  if (path.startsWith('/calendar/') &&
      !canManageSchoolCalendar(normalizedRole)) {
    return false;
  }
  if (path.startsWith('/academics/years/') &&
      !canManageSchoolCalendar(normalizedRole)) {
    return false;
  }
  final allowedPrefixes = _roleRouteAccess[normalizedRole];

  if (allowedPrefixes == null) {
    return false;
  }

  // Check if the path starts with any of the allowed prefixes
  return allowedPrefixes.any((prefix) => path.startsWith(prefix));
}

// ── Auth router notifier ─────────────────────────────────────────────────────

/// Bridges Riverpod [AuthState] changes to GoRouter's [refreshListenable].
/// Every time auth state changes, GoRouter re-evaluates its redirect logic.
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, next) => notifyListeners());
  }

  final Ref _ref;

  AuthState get authState => _ref.read(authProvider);
}

// ── Router provider ──────────────────────────────────────────────────────────

/// Central [GoRouter] provider.
///
/// Redirect rules:
///   - Unauthenticated       → /login
///   - mustChangePassword    → /change-password
///   - Authenticated + login → homeForRole()
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = notifier.authState;
      final loggedIn = auth.user != null;
      final isLogin = state.matchedLocation == '/login';
      final isForgotPassword = state.matchedLocation == '/forgot-password';
      final isChangePassword = state.matchedLocation == '/change-password';
      final isResetPassword = state.matchedLocation == '/reset-password';

      // Mid-operation - don't redirect yet.
      if (auth.isLoading) return null;

      if (!loggedIn) {
        return isLogin || isForgotPassword || isResetPassword ? null : '/login';
      }

      if (auth.user!.mustChangePassword && !isChangePassword) {
        return '/change-password';
      }

      if (isLogin) return homeForRole(auth.user!.roleName);

      // FIX 5: Role-based route access control
      // Check if the current user's role is allowed to access this route
      if (!_isRouteAllowedForRole(auth.user!.roleName, state.matchedLocation)) {
        // Unauthorized access - redirect to their home page
        return homeForRole(auth.user!.roleName);
      }

      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // ── Authenticated application shell ──────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            _AuthenticatedShell(location: state.matchedLocation, child: child),
        routes: [
          // ── Role home pages ───────────────────────────────────────────────
          GoRoute(
            path: '/admin/home',
            builder: (context, state) => const RoleHome('System Admin'),
          ),
          GoRoute(
            path: '/administrator/home',
            builder: (context, state) => const RoleHome('Administrator'),
          ),
          GoRoute(
            path: '/teacher/home',
            builder: (context, state) => const RoleHome('Teacher'),
          ),
          GoRoute(
            path: '/headteacher/home',
            builder: (context, state) => const RoleHome('Head Teacher'),
          ),
          GoRoute(
            path: '/accountant/home',
            builder: (context, state) => const RoleHome('Accountant'),
          ),
          GoRoute(
            path: '/guardian/home',
            builder: (context, state) => const RoleHome('Guardian'),
          ),

          // ── Super-Admin: user management ──────────────────────────────────────
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const UserManagementPage(),
          ),
          GoRoute(
            path: '/admin/users/create',
            builder: (context, state) => const CreateUserPage(),
          ),
          GoRoute(
            path: '/admin/users/:userId',
            builder: (context, state) =>
                UserDetailsPage(userId: state.pathParameters['userId']!),
          ),
          GoRoute(
            path: '/admin/roles/:roleId/permissions',
            builder: (context, state) => ManagePermissionsPage(
              roleId: state.pathParameters['roleId']!,
              roleName: state.uri.queryParameters['roleName'] ?? 'Role',
            ),
          ),

          // ── Academic management ───────────────────────────────────────────────
          GoRoute(
            path: '/academics/years',
            builder: (context, state) => const AcademicYearListPage(),
          ),
          GoRoute(
            path: '/academics/years/new',
            builder: (context, state) => const AcademicYearFormPage(),
          ),
          GoRoute(
            path: '/academics/years/:id/edit',
            builder: (context, state) {
              final year = state.extra as AcademicYear?;
              return AcademicYearFormPage(existing: year);
            },
          ),
          GoRoute(
            path: '/academics/classes',
            builder: (context, state) => const ClassListPage(),
          ),
          GoRoute(
            path: '/academics/classes/new',
            builder: (context, state) => const ClassFormPage(),
          ),
          GoRoute(
            path: '/academics/classes/:id/edit',
            builder: (context, state) =>
                ClassFormPage(existing: state.extra as ClassModel?),
          ),
          GoRoute(
            path: '/academics/subjects',
            builder: (context, state) => const SubjectListPage(),
          ),
          GoRoute(
            path: '/academics/subjects/new',
            builder: (context, state) => const SubjectFormPage(),
          ),
          GoRoute(
            path: '/academics/subjects/:id/edit',
            builder: (context, state) =>
                SubjectFormPage(existing: state.extra as Subject?),
          ),

          // ── Finance management ────────────────────────────────────────────────
          GoRoute(
            path: '/finance/payments',
            builder: (context, state) => const AllPaymentsPage(),
          ),
          GoRoute(
            path: '/finance/payment-configuration',
            builder: (context, state) => const PaymentConfigurationPage(),
          ),
          GoRoute(
            path: '/finance/fees',
            builder: (context, state) => const FeeStructureListPage(
              academicYearId: 'current',
              academicYearLabel: 'Current Year',
            ),
          ),
          GoRoute(
            path: '/finance/fees/:yearId/:id/edit',
            builder: (context, state) => FeeStructureFormPage(
              academicYearId: state.pathParameters['yearId']!,
              existing: state.extra as FeeStructure?,
            ),
          ),
          GoRoute(
            path: '/finance/fees/:yearId/new',
            builder: (context, state) => FeeStructureFormPage(
              academicYearId: state.pathParameters['yearId']!,
            ),
          ),
          GoRoute(
            path: '/finance/students/:studentId/account',
            builder: (context, state) => StudentAccountPage(
              studentId: state.pathParameters['studentId']!,
              studentName: state.uri.queryParameters['name'] ?? 'Student',
            ),
          ),
          GoRoute(
            path: '/finance/students/:studentId/pay',
            builder: (context, state) => RecordPaymentPage(
              studentId: state.pathParameters['studentId']!,
              studentName: state.uri.queryParameters['name'] ?? 'Student',
            ),
          ),

          // ── Student management ────────────────────────────────────────────────
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentListPage(),
          ),
          GoRoute(
            path: '/teacher/classes/:classId/students/:yearId',
            builder: (context, state) => TeacherClassStudentsPage(
              classId: state.pathParameters['classId']!,
              academicYearId: state.pathParameters['yearId']!,
              className: state.uri.queryParameters['className'] ?? 'Class',
              academicYearLabel:
                  state.uri.queryParameters['year'] ?? 'Academic year',
            ),
          ),
          GoRoute(
            path: '/students/new',
            builder: (context, state) => const StudentFormPage(),
          ),
          GoRoute(
            path: '/students/:id/edit',
            builder: (context, state) =>
                StudentFormPage(existing: state.extra as Student?),
          ),
          GoRoute(
            path: '/students/:studentId',
            builder: (context, state) => StudentDetailsPage(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
          GoRoute(
            path: '/students/:studentId/link-guardian',
            builder: (context, state) =>
                GuardianLinkPage(studentId: state.pathParameters['studentId']!),
          ),
          GoRoute(
            path: '/students/:studentId/subjects',
            builder: (context, state) => StudentSubjectsPage(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
          GoRoute(
            path: '/students/:studentId/class-history',
            builder: (context, state) =>
                ClassHistoryPage(studentId: state.pathParameters['studentId']!),
          ),
          GoRoute(
            path: '/students/:studentId/class-history/promote',
            builder: (context, state) => PromoteStudentPage(
              studentId: state.pathParameters['studentId']!,
            ),
          ),

          // ── Staff management ──────────────────────────────────────────────────
          GoRoute(
            path: '/users/staff',
            builder: (context, state) => const StaffListPage(),
          ),
          GoRoute(
            path: '/users/staff/new',
            builder: (context, state) => const StaffFormPage(),
          ),
          GoRoute(
            path: '/users/staff/:id/edit',
            builder: (context, state) =>
                StaffFormPage(existing: state.extra as Staff?),
          ),

          // ── Guardian management ───────────────────────────────────────────────
          GoRoute(
            path: '/users/guardians',
            builder: (context, state) => const GuardianListPage(),
          ),
          GoRoute(
            path: '/users/guardians/:id/edit',
            builder: (context, state) => state.extra is Guardian
                ? GuardianFormPage(existing: state.extra as Guardian)
                : const Scaffold(
                    body: Center(
                      child: Text('Open a guardian from the list to edit.'),
                    ),
                  ),
          ),

          // ── Calendar ──────────────────────────────────────────────────────────
          GoRoute(
            path: '/calendar',
            builder: (context, state) => const CalendarPage(),
          ),
          GoRoute(
            path: '/calendar/new',
            builder: (context, state) => const CalendarEventFormPage(),
          ),
          GoRoute(
            path: '/calendar/:eventId/edit',
            builder: (context, state) =>
                _CalendarEditLoader(eventId: state.pathParameters['eventId']!),
          ),

          // ── Assessments & Grades ──────────────────────────────────────────────
          GoRoute(
            path: '/assessments',
            builder: (context, state) => const AssessmentsPage(),
          ),
          GoRoute(
            path: '/assessments/:assessmentId/grades',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return GradeEntryPage(
                assessmentId: state.pathParameters['assessmentId']!,
                assessmentName:
                    extra['assessmentName'] as String? ?? 'Assessment',
                maxScore: (extra['maxScore'] as num?)?.toDouble() ?? 100,
                classSubjectId: extra['classSubjectId'] as String? ?? '',
                className: extra['className'] as String? ?? 'Class',
                subjectName: extra['subjectName'] as String? ?? 'Subject',
              );
            },
          ),

          // ── Progression & Weeding reviews ─────────────────────────────────────
          GoRoute(
            path: '/progression/reviews',
            builder: (context, state) => const ProgressionReviewsPage(),
          ),
          GoRoute(
            path: '/weeding/reviews',
            builder: (context, state) => const WeedingReviewsPage(),
          ),

          // ── Class assignments ─────────────────────────────────────────────────
          GoRoute(
            path: '/academics/assignments',
            builder: (context, state) => const ClassAssignmentPage(),
          ),

          // ── Communications ────────────────────────────────────────────────────
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/teacher/comments',
            builder: (context, state) => const TeacherCommentPage(),
          ),

          // ── Guardian-specific ─────────────────────────────────────────────────
          GoRoute(
            path: '/guardian/payments',
            builder: (context, state) => const GuardianPaymentHistoryPage(),
          ),
          GoRoute(
            path: '/guardian/progress',
            builder: (context, state) => const GuardianAcademicProgressPage(),
          ),
          GoRoute(
            path: '/guardian/report-card',
            builder: (context, state) => const GuardianReportCardPage(),
          ),

          // ── Admin: Audit log ──────────────────────────────────────────────────
          GoRoute(
            path: '/admin/audit-log',
            builder: (context, state) => const AuditLogPage(),
          ),

          // ── Reports ───────────────────────────────────────────────────────────
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
        ],
      ),
    ],
  );
});

class _AuthenticatedShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const _AuthenticatedShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: auth.isLoading
              ? const CircularProgressIndicator()
              : Text(auth.errorMessage ?? 'Unable to load your account.'),
        ),
      );
    }
    if (location.endsWith('/home')) return child;

    return AppShell(homeRoute: homeForRole(user.roleName), body: child);
  }
}

// ── Helper widget to load an event then open the edit form ────────────────────

class _CalendarEditLoader extends ConsumerWidget {
  final String eventId;
  const _CalendarEditLoader({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_calendarEventProvider(eventId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Event')),
        body: Center(child: Text('Error loading event: $e')),
      ),
      data: (event) => CalendarEventFormPage(existingEvent: event),
    );
  }
}

final _calendarEventProvider = FutureProvider.family((
  ref,
  String eventId,
) async {
  return CalendarRepository().getById(eventId);
});
