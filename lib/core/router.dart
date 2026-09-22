import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../features/academics/presentation/pages/class_list_page.dart';
import '../features/academics/presentation/pages/class_form_page.dart';
import '../features/academics/presentation/pages/subject_list_page.dart';
import '../features/academics/presentation/pages/subject_form_page.dart';
import '../features/finance/presentation/pages/all_payments_page.dart';
import '../features/finance/presentation/pages/fee_structure_list_page.dart';
import '../features/finance/presentation/pages/record_payment_page.dart';
import '../features/finance/presentation/pages/student_account_page.dart';
import '../features/students/presentation/student_list_page.dart';
import '../features/students/presentation/student_form_page.dart';
import '../features/students/presentation/student_details_page.dart';
import '../features/students/presentation/guardian_link_page.dart';
import '../features/students/presentation/class_history_page.dart';
import '../features/users/presentation/pages/staff_list_page.dart';
import '../features/users/presentation/pages/staff_form_page.dart';
import '../features/users/presentation/pages/guardian_list_page.dart';
import '../features/users/presentation/pages/guardian_form_page.dart';
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

/// Returns the initial route path for a given [role] name (from the database).
String homeForRole(String role) {
  switch (role.trim().toUpperCase()) {
    case 'ADMINISTRATOR':
    case 'REGISTRAR':
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
    case 'SYSTEM_ADMIN':
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
    '/assessments',
    '/progression/',
    '/weeding/',
    '/notifications',
    '/teacher/comments',
    '/reports',
  ],
  'SYSTEM_ADMIN': [
    '/admin/',
    '/administrator/',
    '/teacher/',
    '/headteacher/',
    '/accountant/',
    '/students',
    '/users/',
    '/academics/',
    '/finance/',
    '/calendar',
    '/assessments',
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
    '/assessments',
    '/progression/',
    '/weeding/',
    '/notifications',
    '/teacher/comments',
    '/reports',
  ],
  'REGISTRAR': [
    '/administrator/',
    '/students',
    '/users/',
    '/academics/',
    '/calendar',
    '/assessments',
    '/notifications',
  ],
  'HEAD_TEACHER': [
    '/headteacher/',
    '/students',
    '/users/',
    '/academics/',
    '/calendar',
    '/assessments',
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
  'GUARDIAN': ['/guardian/', '/notifications'],
};

/// Checks if a user with the given [role] is allowed to access the [path].
/// Returns true if allowed, false otherwise.
bool _isRouteAllowedForRole(String role, String path) {
  // Public routes (login, change-password) are always allowed
  if (path == '/login' || path == '/change-password') {
    return true;
  }

  final normalizedRole = role.trim().toUpperCase();
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
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
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
      final isChangePassword = state.matchedLocation == '/change-password';

      // Mid-operation - don't redirect yet.
      if (auth.isLoading) return null;

      if (!loggedIn) return isLogin ? null : '/login';

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
        path: '/change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // ── Role home pages ───────────────────────────────────────────────────
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
        path: '/academics/classes',
        builder: (context, state) => const ClassListPage(),
      ),
      GoRoute(
        path: '/academics/classes/new',
        builder: (context, state) => const ClassFormPage(),
      ),
      GoRoute(
        path: '/academics/subjects',
        builder: (context, state) => const SubjectListPage(),
      ),
      GoRoute(
        path: '/academics/subjects/new',
        builder: (context, state) => const SubjectFormPage(),
      ),

      // ── Finance management ────────────────────────────────────────────────
      GoRoute(
        path: '/finance/payments',
        builder: (context, state) => const AllPaymentsPage(),
      ),
      GoRoute(
        path: '/finance/fees',
        builder: (context, state) => const FeeStructureListPage(
          academicYearId: 'current',
          academicYearLabel: 'Current Year',
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
        path: '/students/new',
        builder: (context, state) => const StudentFormPage(),
      ),
      GoRoute(
        path: '/students/:studentId',
        builder: (context, state) =>
            StudentDetailsPage(studentId: state.pathParameters['studentId']!),
      ),
      GoRoute(
        path: '/students/:studentId/link-guardian',
        builder: (context, state) =>
            GuardianLinkPage(studentId: state.pathParameters['studentId']!),
      ),
      GoRoute(
        path: '/students/:studentId/class-history',
        builder: (context, state) =>
            ClassHistoryPage(studentId: state.pathParameters['studentId']!),
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

      // ── Guardian management ───────────────────────────────────────────────
      GoRoute(
        path: '/users/guardians',
        builder: (context, state) => const GuardianListPage(),
      ),
      GoRoute(
        path: '/users/guardians/new',
        builder: (context, state) => const GuardianFormPage(),
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
            assessmentName: extra['assessmentName'] as String? ?? 'Assessment',
            maxScore: (extra['maxScore'] as num?)?.toDouble() ?? 100,
            classSubjectId: extra['classSubjectId'] as String? ?? '',
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
  );
});

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
