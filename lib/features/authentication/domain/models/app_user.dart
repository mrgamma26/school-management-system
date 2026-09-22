/// Typed application user loaded from [systemuser] joined with [role].
class AppUser {
  final String userId;
  final String username;
  final String roleId;
  final String roleName;
  final bool mustChangePassword;
  final bool isActive;

  const AppUser({
    required this.userId,
    required this.username,
    required this.roleId,
    required this.roleName,
    required this.mustChangePassword,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    userId: json['userid'] as String,
    username: json['username'] as String,
    roleId: json['roleid'] as String,
    roleName: (json['role'] as Map<String, dynamic>)['rolename'] as String,
    mustChangePassword: json['mustchangepassword'] as bool,
    isActive: json['isactive'] as bool,
  );

  @override
  String toString() =>
      'AppUser(userId: $userId, username: $username, roleName: $roleName)';
}
