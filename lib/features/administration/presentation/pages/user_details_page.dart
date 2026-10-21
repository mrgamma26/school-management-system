import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../users/data/repositories/user_repository.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../widgets/can.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';

final _userDetailsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
      return UserRepository().getSystemUserWithDetails(userId);
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
  bool? _optimisticIsActive;

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
    if (!mounted) return;
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
                      // ignore: deprecated_member_use
                      groupValue: isCurrent ? role : null,
                      // ignore: deprecated_member_use
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

    // Confirm the role change — guard context use after the previous await.
    if (!mounted) return;
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
      if (mounted) setState(() => _loading = false);
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

    setState(() {
      _loading = true;
      _optimisticIsActive = !isActive;
    });
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

      final refreshedUser = await ref.refresh(
        _userDetailsProvider(widget.userId).future,
      );
      if (refreshedUser['isactive'] != !isActive) {
        throw StateError('The account status did not update.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _optimisticIsActive = null;
        });
      }
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

    return async.when(
      loading: () => const UiPage(
        children: [
          PageHead(kicker: 'Administration', title: 'User Details'),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading user…'),
          ),
        ],
      ),
      error: (e, _) => UiPage(
        children: [
          const PageHead(kicker: 'Administration', title: 'User Details'),
          ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_userDetailsProvider(widget.userId)),
          ),
        ],
      ),
      data: (user) {
        final role = user['role'] as Map<String, dynamic>?;
        final staff = user['staff'] as Map<String, dynamic>?;
        final guardian = user['guardian'] as Map<String, dynamic>?;
        final isActive = _optimisticIsActive ?? user['isactive'] as bool;
        final mustChange = user['mustchangepassword'] as bool;
        final profile = staff ?? guardian;
        final displayName = profile == null
            ? '${user['username']}'
            : '${profile['firstname']} ${profile['lastname']}';

        return UiPage(
          children: [
            PageHead(
              kicker: 'Administration',
              title: 'User Details',
              subtitle: 'Account, profile and role for this user.',
              actions: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                // FIX 4: Change Role button
                Can(
                  permission: 'permissions:manage',
                  child: UiButton.secondary(
                    'Change Role',
                    icon: Icons.swap_horiz,
                    onPressed: _loading ? null : () => _changeRole(user),
                  ),
                ),
                Can(
                  permission: 'users:deactivate',
                  child: UiButton.secondary(
                    isActive ? 'Deactivate User' : 'Reactivate User',
                    icon: isActive ? Icons.block : Icons.check_circle,
                    onPressed: _loading ? null : () => _toggleUserStatus(user),
                  ),
                ),
                Can(
                  permission: 'users:reset_password',
                  child: UiButton.secondary(
                    'Reset Password',
                    icon: Icons.lock_reset,
                    onPressed: _loading ? null : _resetPassword,
                  ),
                ),
              ],
            ),
            ProfileHero(
              name: displayName,
              subtitle: '${user['username']} • ${role?['rolename'] ?? 'No Role'}',
              pill: StatusPill(
                isActive ? 'Active' : 'Inactive',
                tone: isActive ? StatusTone.success : StatusTone.danger,
              ),
            ),
            const SizedBox(height: 14),
            AdaptiveGrid(
              columns: 2,
              mediumColumns: 2,
              gap: 14,
              children: [
                _infoCard('Account Information', [
                  _infoRow('Username', user['username']),
                  _infoRow('Role', role?['rolename'] ?? 'No Role'),
                  _infoRow('Must Change Password', mustChange ? 'Yes' : 'No'),
                  _infoRow('Created', _formatDate(user['createdat'])),
                  if (user['updatedat'] != null)
                    _infoRow('Updated', _formatDate(user['updatedat'])),
                ]),
                if (profile != null)
                  _infoCard(
                    staff != null ? 'Staff Profile' : 'Guardian Profile',
                    [
                      _infoRow('First Name', profile['firstname']),
                      _infoRow('Last Name', profile['lastname']),
                      _infoRow('Email', profile['email']),
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
                if (role != null)
                  _infoCard('Role Details', [
                    _infoRow('Role Name', role['rolename']),
                    if (role['description'] != null)
                      _infoRow('Description', role['description']),
                  ]),
                // ── Permissions management ────────────────────
                Panel(
                  title: 'Role Permissions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Grant or revoke individual permissions for the '
                        '"${role?['rolename'] ?? 'assigned'}" role. '
                        'Changes apply to ALL users with this role.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Can(
                        permission: 'permissions:manage',
                        child: UiButton(
                          'Manage Role Permissions',
                          icon: Icons.admin_panel_settings,
                          onPressed: role == null
                              ? null
                              : () => context.go(
                                  '/admin/roles/${role['roleid']}/permissions?roleName=${Uri.encodeComponent(role['rolename'] as String)}',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Panel(
      title: title,
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String? value) =>
      DetailLine(label, value ?? 'Not set');

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    final date = DateTime.parse(isoDate);
    return '${formatUiDate(date)} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
