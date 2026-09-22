/// Represents an application role loaded from the [role] table.
class AppRole {
  final String roleId;
  final String roleName;
  final String? description;

  const AppRole({
    required this.roleId,
    required this.roleName,
    this.description,
  });

  factory AppRole.fromJson(Map<String, dynamic> json) => AppRole(
    roleId: json['roleid'] as String,
    roleName: json['rolename'] as String,
    description: json['description'] as String?,
  );

  @override
  String toString() => 'AppRole(roleId: $roleId, roleName: $roleName)';
}
