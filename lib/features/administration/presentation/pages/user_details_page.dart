import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../users/data/repositories/user_repository.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'manage_permissions_page.dart';

final _userDetailsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
      return await supabase
          .from('systemuser')
          .select('''
        userid, username, mustchangepassword, isactive, createdat, updatedat,
        role(roleid, rolename, description),
        staff(staffid, firstname, lastname, email, employeenumber),
        guardian(guardianid, firstname, lastname, email, phonenumber, physicaladdress)
      ''')
          .eq('userid', userId)
          .single();
    });

/// Detailed view of a system user with admin controls.
class UserDetailsPage extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailsPage({required this.userId, super.key});

  @override
  ConsumerState<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends ConsumerState<UserDetailsPage> {
  final _repo = UserRepository();
  bool _loading = false;

  // FIX 4: Role change functionality
  Future<void> _changeRole(Map<String, dynamic> user) async {
    final currentRole = user['role'] as Map<String, dynamic>?;
    final currentRoleName = currentRole?['rolename'] as String? ?? 'No Role';

    // Load available roles
    List<Map<String, dynamic>> roles;
    try {
      roles = await _repo.listRoles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading roles: $e')));
      }
      return;
    }

    // Show role selection dialog
    final selectedRole = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change User Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current role: $currentRoleName'),
            const SizedBox(height: 16),
            const Text(
              'Select new role:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  children: roles.map((role) {
                    final roleId = role['roleid'] as String;
                    final roleName = role['rolename'] as String;
                    final isCurrent = roleId == currentRole?['roleid'];
                    return RadioListTile<Map<String, dynamic>>(
                      title: Text(roleName),
                      value: role,
                      groupValue: isCurrent ? role : null,
                      onChanged: isCurrent
                          ? null
                          : (value) => Navigator.pop(ctx, value),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedRole == null) return;

    // Confirm the role change
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Role Change'),
        content: Text(
          'Change user role from "$currentRoleName" to "${selectedRole['rolename']}"?\n\n'
          'This will immediately change the user\'s permissions and access level.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Change Role'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Perform role change
    setState(() => _loading = true);
    try {
      await _repo.changeUserRole(
        widget.userId,
        selectedRole['roleid'] as String,
      );

      // Log the action
      final currentUser = ref.read(authProvider).user!;
      await AuditService().log(
        userId: currentUser.userId,
        action: 'USER_ROLE_CHANGED',
        tableName: 'systemuser',
        recordId: widget.userId,
        actorRole: currentUser.roleName,
        previousValue: {'role': currentRoleName},
        newValue: {'role': selectedRole['rolename']},
      );

      ref.invalidate(_userDetailsProvider(widget.userId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Role changed to ${selectedRole['rolename']} successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error changing role: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final isActive = user['isactive'] as bool;
    final action = isActive ? 'deactivate' : 'activate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${action.substring(0, 1).toUpperCase()}${action.substring(1)} User',
        ),
        content: Text('Are you sure you want to $action this user account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action.substring(0, 1).toUpperCase() + action.substring(1),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      if (isActive) {
        await _repo.deactivateUser(widget.userId);
      } else {
        await _repo.reactivateUser(widget.userId);
      }

      // Log the action
      final currentUser = ref.read(authProvider).user!;
      await AuditService().log(
        userId: currentUser.userId,
        action: isActive ? 'USER_DEACTIVATED' : 'USER_REACTIVATED',
        tableName: 'systemuser',
        recordId: widget.userId,
        actorRole: currentUser.roleName,
      );

      ref.invalidate(_userDetailsProvider(widget.userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter new password for this user:'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, passwordCtrl.text.trim());
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    passwordCtrl.dispose();
    if (confirmed == null) return;

    setState(() => _loading = true);
    try {
      await _repo.resetPassword(
        targetUserId: widget.userId,
        newPassword: confirmed,
      );

      // Log the action
      final currentUser = ref.read(authProvider).user!;
      await AuditService().log(
        userId: currentUser.userId,
        action: 'PASSWORD_RESET',
        tableName: 'systemuser',
        recordId: widget.userId,
        actorRole: currentUser.roleName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_userDetailsProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          final role = user['role'] as Map<String, dynamic>?;
          final staff = user['staff'] as Map<String, dynamic>?;
          final guardian = user['guardian'] as Map<String, dynamic>?;
          final isActive = user['isactive'] as bool;
          final mustChange = user['mustchangepassword'] as bool;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Basic Info Card
                _infoCard('Account Information', [
                  _infoRow('Username', user['username']),
                  _infoRow('Role', role?['rolename'] ?? 'No Role'),
                  _infoRow('Must Change Password', mustChange ? 'Yes' : 'No'),
                  _infoRow('Created', _formatDate(user['createdat'])),
                  if (user['updatedat'] != null)
                    _infoRow('Updated', _formatDate(user['updatedat'])),
                ]),

                // Profile Info Card
                if (staff != null || guardian != null) ...[
                  const SizedBox(height: 16),
                  _infoCard(
                    staff != null ? 'Staff Profile' : 'Guardian Profile',
                    [
                      _infoRow('First Name', (staff ?? guardian)!['firstname']),
                      _infoRow('Last Name', (staff ?? guardian)!['lastname']),
                      _infoRow('Email', (staff ?? guardian)!['email']),
                      if (staff != null)
                        _infoRow('Employee Number', staff['employeenumber']),
                      if (guardian != null) ...[
                        if (guardian['phonenumber'] != null)
                          _infoRow('Phone', guardian['phonenumber']),
                        if (guardian['physicaladdress'] != null)
                          _infoRow('Address', guardian['physicaladdress']),
                      ],
                    ],
                  ),
                ],

                // Role Details Card
                if (role != null) ...[
                  const SizedBox(height: 16),
                  _infoCard('Role Details', [
                    _infoRow('Role Name', role['rolename']),
                    if (role['description'] != null)
                      _infoRow('Description', role['description']),
                  ]),
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // FIX 4: Change Role button
                    ElevatedButton.icon(
                      onPressed: _loading ? null : () => _changeRole(user),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Change Role'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _toggleUserStatus(user),
                      icon: Icon(isActive ? Icons.block : Icons.check_circle),
                      label: Text(
                        isActive ? 'Deactivate User' : 'Reactivate User',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _resetPassword,
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Reset Password'),
                    ),
                    const SizedBox(height: 8),

                    // ── Permissions management ────────────────────
                    const Divider(height: 24),
                    const Text(
                      'Role Permissions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Grant or revoke individual permissions for the '
                      '"${role?['rolename'] ?? 'assigned'}" role. '
                      'Changes apply to ALL users with this role.',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: role == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManagePermissionsPage(
                                  roleId: role['roleid'] as String,
                                  roleName: role['rolename'] as String,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Manage Role Permissions'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value ?? 'Not set')),
        ],
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    final date = DateTime.parse(isoDate);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
