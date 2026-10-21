import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audit_service.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../users/data/repositories/user_repository.dart';

// ── Providers ────────────────────────────────────────────────────────────────

/// Loads the role record (name + existing permissions) for [roleId].
final _rolePermissionsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, roleId) async {
      return UserRepository().getRoleWithPermissions(roleId);
    });

// ── Canonical permission catalogue ───────────────────────────────────────────

/// Every permission the system supports, grouped by domain.
/// The super-admin UI renders these as toggles.
const _permissionCatalogue = <String, List<String>>{
  'Students': [
    'students:read',
    'students:write',
    'students:delete',
    'students:enrol',
    'students:withdraw',
  ],
  'Staff': ['staff:read', 'staff:write', 'staff:delete'],
  'Guardians': [
    'guardians:read',
    'guardians:write',
    'guardians:delete',
    'guardians:link_student',
  ],
  'Academics': [
    'academics:read',
    'academics:write',
    'academics:delete',
    'classes:assign_teacher',
  ],
  'Finance': [
    'finance:read',
    'finance:record_payment',
    'finance:adjust_fees',
    'finance:manage_structures',
    'finance:reports',
  ],
  'Assessments & Grades': [
    'grades:read',
    'grades:write',
    'grades:approve',
    'assessments:read',
    'assessments:write',
  ],
  'Progression & Weeding': [
    'progression:read',
    'progression:decide',
    'weeding:read',
    'weeding:decide',
  ],
  'User Management': [
    'users:read',
    'users:create',
    'users:deactivate',
    'users:reset_password',
    'permissions:manage',
  ],
  'Audit Log': ['auditlog:read'],
};

// ── Page ─────────────────────────────────────────────────────────────────────

/// Screen 17 - Permissions for a single role.
/// Reached from [UserDetailsPage] → "Manage Permissions" button.
/// Only accessible by SUPER_USER.
class ManagePermissionsPage extends ConsumerStatefulWidget {
  final String roleId;
  final String roleName;

  const ManagePermissionsPage({
    required this.roleId,
    required this.roleName,
    super.key,
  });

  @override
  ConsumerState<ManagePermissionsPage> createState() =>
      _ManagePermissionsPageState();
}

class _ManagePermissionsPageState extends ConsumerState<ManagePermissionsPage> {
  /// Local set of currently granted permission names — edited by toggles.
  Set<String> _granted = {};

  /// Set as loaded from DB — used to compute diff on save.
  Set<String> _original = {};

  /// permissionid lookup: name → id (for existing rows we need to DELETE).
  Map<String, String> _permissionIds = {};

  bool _initialised = false;
  bool _saving = false;
  String? _error;

  // ── Lifecycle ───────────────────────────────────────────────────────────

  void _initFromData(Map<String, dynamic> data) {
    if (_initialised) return;
    final perms = (data['rolepermission'] as List<dynamic>?) ?? [];
    final names = perms
        .map((p) => (p as Map<String, dynamic>)['permissionname'] as String)
        .toSet();
    final ids = <String, String>{};
    for (final p in perms) {
      ids[p['permissionname'] as String] = p['permissionid'] as String;
    }
    setState(() {
      _granted = Set.of(names);
      _original = Set.of(names);
      _permissionIds = ids;
      _initialised = true;
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final toAdd = _granted.difference(_original);
    final toRemove = _original.difference(_granted);

    if (toAdd.isEmpty && toRemove.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes to save.')));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = UserRepository();

      // Insert new permissions
      if (toAdd.isNotEmpty) {
        await repo.addPermissionsToRole(widget.roleId, toAdd.toList());
      }

      // Delete removed permissions by their permissionid
      for (final name in toRemove) {
        final id = _permissionIds[name];
        if (id != null) {
          await repo.removePermissionFromRole(id);
        }
      }

      // Audit log
      final actor = ref.read(authProvider).user!;
      await AuditService().log(
        userId: actor.userId,
        action: 'ROLE_PERMISSIONS_UPDATED',
        tableName: 'rolepermission',
        recordId: widget.roleId,
        actorRole: actor.roleName,
        previousValue: {'permissions': _original.toList()..sort()},
        newValue: {'permissions': _granted.toList()..sort()},
        reason: 'Permission update via admin UI',
      );

      // Commit local state
      _original = Set.of(_granted);
      ref.invalidate(_rolePermissionsProvider(widget.roleId));
      if (actor.roleId == widget.roleId) {
        ref.invalidate(permissionsProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Permissions updated: +${toAdd.length} added, '
              '-${toRemove.length} removed.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool get _isDirty =>
      _granted != _original &&
      (!_granted.containsAll(_original) || !_original.containsAll(_granted));

  void _toggleAll(List<String> perms, bool grant) {
    setState(() {
      if (grant) {
        _granted.addAll(perms);
      } else {
        _granted.removeAll(perms);
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_rolePermissionsProvider(widget.roleId));

    return UiPage(
      children: [
        PageHead(
          kicker: 'Users & Access',
          title: 'Manage Permissions',
          subtitle: '${widget.roleName} role · protected capabilities by area.',
          actions: [
            UiButton(
              _saving ? 'Saving…' : 'Save permissions',
              icon: Icons.save_outlined,
              onPressed: _initialised && !_saving ? _save : null,
            ),
          ],
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading permissions…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () =>
                ref.invalidate(_rolePermissionsProvider(widget.roleId)),
          ),
          data: (data) {
            _initFromData(data);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isDirty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: UiCard(
                      color: AppColors.warningSurface,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'You have unsaved permission changes.',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _granted = Set.of(_original)),
                            child: const Text('Discard'),
                          ),
                          TextButton(
                            onPressed: _save,
                            child: const Text('Save now'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: UiNotice('Error: $_error'),
                  ),
                AdaptiveGrid(
                  columns: 2,
                  mediumColumns: 2,
                  gap: 14,
                  children: [
                    for (final entry in _permissionCatalogue.entries)
                      _domainPanel(entry.key, entry.value),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _domainPanel(String domain, List<String> perms) {
    final grantedCount = perms.where((p) => _granted.contains(p)).length;
    return Panel(
      title: domain,
      trailing: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusPill(
            '$grantedCount / ${perms.length} granted',
            tone: grantedCount == perms.length
                ? StatusTone.success
                : grantedCount == 0
                ? StatusTone.neutral
                : StatusTone.warning,
          ),
          TextButton(
            onPressed: () => _toggleAll(perms, true),
            child: const Text('All'),
          ),
          TextButton(
            onPressed: () => _toggleAll(perms, false),
            child: const Text('None'),
          ),
        ],
      ),
      child: QueueList(
        items: [
          for (final perm in perms)
            CheckRow(
              label: perm,
              checked: _granted.contains(perm),
              onChanged: (checked) => setState(() {
                checked ? _granted.add(perm) : _granted.remove(perm);
              }),
            ),
        ],
      ),
    );
  }
}
