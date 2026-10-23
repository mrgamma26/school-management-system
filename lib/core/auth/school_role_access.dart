/// Role rules shared by navigation, routes and event forms.
String schoolRole(String role) {
  final normalized = role.trim().toUpperCase();
  return normalized == 'SYSTEM_ADMIN' ? 'SUPER_USER' : normalized;
}

bool canManageSchoolCalendar(String role) =>
    const {'SUPER_USER', 'ADMINISTRATOR', 'ADMIN'}.contains(schoolRole(role));

/// Sending in-app notices to guardians: the roles that already read every
/// notice (`notification` RLS "privileged roles can read all notifications").
bool canSendNotifications(String role) => const {
  'SUPER_USER',
  'ADMINISTRATOR',
  'HEAD_TEACHER',
}.contains(schoolRole(role));

/// Permissions the screens treat as implied by a school role, on top of the
/// rows in `rolepermission` (which only cover Accountant, Head Teacher,
/// Teacher and a stub for Super User). Each entry mirrors what row-level
/// security already allows that role, so the UI shows exactly the actions the
/// database accepts:
///  * `staff`, `guardian` and `subject` tables: Super User + Administrator manage;
///  * `feestructure`: Super User, Administrator and Accountant manage;
///  * `systemuser` and `auditlog` are read by the Super User;
///  * students are registered and moved between terms by Super User and
///    Administrator (`students:enrol`).
Set<String> impliedPermissionsFor(String role) {
  switch (schoolRole(role)) {
    case 'SUPER_USER':
      return const {
        'users:read',
        'auditlog:read',
        'staff:write',
        'guardians:write',
        'academics:write',
        'finance:manage_structures',
        'students:enrol',
      };
    case 'ADMINISTRATOR':
      return const {
        'staff:write',
        'guardians:write',
        'academics:write',
        'finance:manage_structures',
        'students:enrol',
      };
    default:
      return const {};
  }
}

bool canAccessSchoolReviews(String role) => schoolRole(role) == 'HEAD_TEACHER';

bool canManageAcademicSetup(String role) =>
    const {'SUPER_USER', 'ADMINISTRATOR'}.contains(schoolRole(role));

/// Student payment accounts and payment recording belong to accountants only.
///
/// Administrators keep their read-only finance reports and configuration
/// access, but must not enter the per-student payment workflow.
bool canRecordStudentPayments(String role) => schoolRole(role) == 'ACCOUNTANT';

/// Result corrections: teachers raise and complete them, the Head Teacher
/// (or Super User) decides them. Matches the `result_correction_requests` RLS.
bool canViewResultCorrections(String role) =>
    const {'SUPER_USER', 'HEAD_TEACHER', 'TEACHER'}.contains(schoolRole(role));

bool canDecideResultCorrections(String role) =>
    const {'SUPER_USER', 'HEAD_TEACHER'}.contains(schoolRole(role));

bool canCompleteResultCorrections(String role) => schoolRole(role) == 'TEACHER';

/// Publishing results is limited to the Head Teacher and Super User, the same
/// roles `publish_assessment_results` accepts.
bool canPublishResults(String role) =>
    const {'SUPER_USER', 'HEAD_TEACHER'}.contains(schoolRole(role));

/// The review workspace (`/results/review`) exists to approve and publish
/// submitted result sheets, so it opens for the same roles as publishing.
bool canReviewSubmittedResults(String role) => canPublishResults(role);

/// The developer guidance pages (`/admin/roles-map`, `/admin/supabase-setup`)
/// are for the Super User only.
bool canViewSystemGuides(String role) => schoolRole(role) == 'SUPER_USER';

/// Routes every signed-in role may open: the personal profile and help pages.
bool isSharedAccountRoute(String path) => path == '/profile' || path == '/help';

/// Human-readable role name ("Head Teacher") for headers and profile pages.
String schoolRoleLabel(String role) {
  final words = schoolRole(role)
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((word) => word.isNotEmpty);
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
