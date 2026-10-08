import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../users/data/repositories/user_repository.dart';
import '../../../../widgets/skeleton_loader.dart';

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

/// Full permission management screen for a single role.
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Permissions'),
            Text(
              widget.roleName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _initialised ? _save : null,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonListLoader(itemCount: 5, itemHeight: 72),
        error: (e, _) => Center(child: Text('Error loading permissions: $e')),
        data: (data) {
          _initFromData(data);

          return Column(
            children: [
              // Dirty-state banner
              if (_isDirty)
                MaterialBanner(
                  content: const Text('You have unsaved permission changes.'),
                  backgroundColor: Colors.amber.shade50,
                  leading: const Icon(Icons.warning_amber),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() {
                        _granted = Set.of(_original);
                      }),
                      child: const Text('Discard'),
                    ),
                    TextButton(onPressed: _save, child: const Text('Save Now')),
                  ],
                ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // Permission list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  children: _permissionCatalogue.entries.map((entry) {
                    final domain = entry.key;
                    final perms = entry.value;
                    final allGranted = perms.every((p) => _granted.contains(p));
                    final someGranted = perms.any((p) => _granted.contains(p));

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ExpansionTile(
                        leading: Icon(
                          allGranted
                              ? Icons.check_circle
                              : someGranted
                              ? Icons.indeterminate_check_box
                              : Icons.radio_button_unchecked,
                          color: allGranted
                              ? Colors.green
                              : someGranted
                              ? Colors.orange
                              : Colors.grey,
                        ),
                        title: Text(
                          domain,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${perms.where((p) => _granted.contains(p)).length}'
                          ' / ${perms.length} granted',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _toggleAll(perms, true),
                              child: const Text('All'),
                            ),
                            TextButton(
                              onPressed: () => _toggleAll(perms, false),
                              child: const Text('None'),
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                        children: perms.map((perm) {
                          final isGranted = _granted.contains(perm);
                          return CheckboxListTile(
                            value: isGranted,
                            title: Text(
                              perm,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                            secondary: Icon(
                              isGranted ? Icons.lock_open : Icons.lock,
                              color: isGranted ? Colors.green : Colors.grey,
                              size: 18,
                            ),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _granted.add(perm);
                                } else {
                                  _granted.remove(perm);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
