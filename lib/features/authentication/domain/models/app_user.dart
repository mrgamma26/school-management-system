/// Typed application user loaded from [systemuser] joined with [role].
class AppUser {
  final String userId;
  final String username;
  final String roleId;
  final String roleName;
  final bool mustChangePassword;
  final bool isActive;
  final Map<String, String> roles;

  const AppUser({
    required this.userId,
    required this.username,
    required this.roleId,
    required this.roleName,
    required this.mustChangePassword,
    required this.isActive,
    this.roles = const {},
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final primaryName =
        (json['role'] as Map<String, dynamic>)['rolename'] as String;
    final assigned = <String, String>{};
    for (final item in json['user_roles'] as List? ?? const []) {
      final row = item as Map<String, dynamic>;
      final role = row['role'] as Map<String, dynamic>;
      assigned[(role['rolename'] as String).trim().toUpperCase()] =
          row['role_id'] as String;
    }
    assigned.putIfAbsent(
      primaryName.trim().toUpperCase(),
      () => json['roleid'] as String,
    );
    return AppUser(
      userId: json['userid'] as String,
      username: json['username'] as String,
      roleId: json['roleid'] as String,
      roleName: primaryName,
      mustChangePassword: json['mustchangepassword'] as bool,
      isActive: json['isactive'] as bool,
      roles: assigned,
    );
  }

  bool get hasWorkspaceSwitcher =>
      roles.containsKey('TEACHER') && roles.containsKey('HEAD_TEACHER');

  String? roleIdFor(String roleName) => roles[roleName.trim().toUpperCase()];

  @override
  String toString() =>
      'AppUser(userId: $userId, username: $username, roleName: $roleName)';
}
