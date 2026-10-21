// Rules for the staff onboarding workspace, kept free of UI and backend code
// so they can be tested directly.
//
// Server-side facts these rules mirror:
// * `create-user` / `private.can_assign_role()`: a Super User may assign any
//   approved role, an Administrator only Teacher, Accountant or Guardian.
// * `user_roles` + `validate_user_role_pair()`: the only permitted two-role
//   combination is Teacher + Head Teacher; `systemuser.roleid` stays primary.
// * `assign_teacher_to_class_subjects()` accepts staff holding TEACHER or
//   HEAD_TEACHER, so those are the roles with teaching assignments.

String _normalise(String? role) => (role ?? '').trim().toUpperCase();

/// True when the picked role can be given class-subject assignments.
bool isTeachingRole(String? roleName) =>
    const {'TEACHER', 'HEAD_TEACHER'}.contains(_normalise(roleName));

/// The "also Head Teacher" dual role is for a Teacher only, and only a Super
/// User may grant it (an Administrator cannot assign Head Teacher).
bool canGrantHeadTeacherDualRole({
  required String? selectedRoleName,
  required String actorRole,
}) =>
    _normalise(selectedRoleName) == 'TEACHER' &&
    const {'SUPER_USER', 'SYSTEM_ADMIN'}.contains(_normalise(actorRole));

/// Whether the dual-role control should be shown at all (a Teacher is picked).
bool showsDualRoleControl(String? selectedRoleName) =>
    _normalise(selectedRoleName) == 'TEACHER';

/// Where a new teacher goes next: Class Setup, where they can now be chosen
/// for the subjects they were marked as teaching.
const classSetupRoute = '/academics/class-setup';
