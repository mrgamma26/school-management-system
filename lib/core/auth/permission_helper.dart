import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';

/// Canonical role hierarchy (higher roles inherit all lower permissions).
enum UserRole {
  guest('GUEST'),
  customer('CUSTOMER'),
  staff('STAFF'),
  manager('MANAGER'),
  admin('ADMIN'),
  superAdmin('SUPER_ADMIN');

  final String displayName;
  const UserRole(this.displayName);

  /// Returns this role's level in the hierarchy (0 = lowest, 5 = highest).
  int get hierarchyLevel => index;

  /// True if this role outranks or equals [other].
  bool outranks(UserRole other) => hierarchyLevel >= other.hierarchyLevel;

  /// True if this role is [other] or higher.
  bool isAtLeast(UserRole other) => outranks(other);

  /// Parse role name (case-insensitive) to enum. Defaults to GUEST if not found.
  static UserRole fromString(String? name) {
    if (name == null) return UserRole.guest;
    final upper = name.toUpperCase();
    try {
      return UserRole.values.firstWhere(
        (r) => r.displayName == upper,
        orElse: () => UserRole.guest,
      );
    } catch (_) {
      return UserRole.guest;
    }
  }
}

/// Centralized permission checking logic.
/// All role-based access control flows through here.
class PermissionHelper {
  final String? roleId;
  final String roleName;
  final Set<String> grantedPermissions;

  const PermissionHelper({
    this.roleId,
    required this.roleName,
    required this.grantedPermissions,
  });

  /// The user's role enum.
  UserRole get role => UserRole.fromString(roleName);

  /// True if user has the given permission.
  bool has(String permission) => grantedPermissions.contains(permission);

  /// True if user has ANY of the given permissions.
  bool hasAny(List<String> permissions) => permissions.any((p) => has(p));

  /// True if user has ALL of the given permissions.
  bool hasAll(List<String> permissions) => permissions.every((p) => has(p));

  /// True if user's role is at least [minRole].
  bool isAtLeast(UserRole minRole) => role.isAtLeast(minRole);

  /// True if user's role exactly matches [targetRole].
  bool isRole(UserRole targetRole) => role == targetRole;

  /// True if user is an admin or above.
  bool get isAdmin => isAtLeast(UserRole.admin);

  /// True if user is a manager or above.
  bool get isManager => isAtLeast(UserRole.manager);

  /// True if user is staff or above.
  bool get isStaff => isAtLeast(UserRole.staff);

  /// True if user is a customer or above (any authenticated user).
  bool get isAuthenticated => isAtLeast(UserRole.customer);

  /// True if user can manage users (create, deactivate, change roles).
  bool get canManageUsers => has('users:write') || isAdmin;

  /// True if user can read user data.
  bool get canReadUsers => has('users:read') || isAtLeast(UserRole.staff);

  /// True if user can manage students (create, update, enroll).
  bool get canManageStudents =>
      has('students:write') || isAtLeast(UserRole.manager);

  /// True if user can read student data.
  bool get canReadStudents => has('students:read') || isAtLeast(UserRole.staff);

  /// True if user can manage assessments/grades.
  bool get canManageAssessments =>
      has('assessments:write') || isAtLeast(UserRole.manager);

  /// True if user can enter grades.
  bool get canEnterGrades => has('grades:write') || isAtLeast(UserRole.staff);

  /// True if user can read assessments/grades.
  bool get canReadAssessments =>
      has('assessments:read') || isAtLeast(UserRole.customer);

  /// True if user can manage finance (fees, payments, adjustments).
  bool get canManageFinance =>
      has('finance:write') || isAtLeast(UserRole.manager);

  /// True if user can record payments.
  bool get canRecordPayments =>
      has('payments:write') || isAtLeast(UserRole.staff);

  /// True if user can read finance data.
  bool get canReadFinance =>
      has('finance:read') || isAtLeast(UserRole.customer);

  /// True if user can make weeding (withdrawal) decisions.
  bool get canDecideWeeding =>
      has('weeding:write') || isAtLeast(UserRole.manager);

  /// True if user can view weeding reviews.
  bool get canViewWeeding => has('weeding:read') || isAtLeast(UserRole.staff);

  /// True if user can make progression decisions.
  bool get canDecideProgression =>
      has('progression:write') || isAtLeast(UserRole.manager);

  /// True if user can view progression reviews.
  bool get canViewProgression =>
      has('progression:read') || isAtLeast(UserRole.staff);

  /// True if user can write comments (teacher-specific).
  bool get canWriteComments =>
      has('comments:write') || roleName.toUpperCase() == 'TEACHER';

  /// True if user can read comments.
  bool get canReadComments => has('comments:read') || isAtLeast(UserRole.staff);

  /// True if user can manage communications.
  bool get canManageCommunications =>
      has('communications:write') || isAtLeast(UserRole.manager);

  /// True if user can export data.
  bool get canExport => has('export:write') || isAtLeast(UserRole.admin);

  @override
  String toString() =>
      'PermissionHelper(role: ${role.displayName}, permissions: ${grantedPermissions.length})';
}

/// Provider: loads current user's permissions and role once on auth.
final permissionHelperProvider = FutureProvider<PermissionHelper?>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return null;

  final permissions = await ref.watch(permissionsProvider.future);
  return PermissionHelper(
    roleId: user.roleId,
    roleName: user.roleName,
    grantedPermissions: permissions,
  );
});
