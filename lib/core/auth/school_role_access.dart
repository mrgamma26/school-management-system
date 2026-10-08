/// Role rules shared by navigation, routes and event forms.
String schoolRole(String role) {
  final normalized = role.trim().toUpperCase();
  return normalized == 'SYSTEM_ADMIN' ? 'SUPER_USER' : normalized;
}

bool canManageSchoolCalendar(String role) =>
    const {'SUPER_USER', 'ADMINISTRATOR', 'ADMIN'}.contains(schoolRole(role));

bool canAccessSchoolReviews(String role) => schoolRole(role) == 'HEAD_TEACHER';
