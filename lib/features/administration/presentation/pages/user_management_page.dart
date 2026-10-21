import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/can.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../users/data/repositories/user_repository.dart';

final _allUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      return UserRepository().listAllSystemUsers();
    });

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

/// Screen 15 - User accounts: status, role and security actions.
class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  static const _pageSize = 20;

  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE'
  String _sortBy = 'date'; // 'date', 'name', 'role', 'status'
  bool _sortAscending = false;
  int _currentPage = 0;

  static const _sortLabels = {
    'date': 'Date created',
    'name': 'Name',
    'role': 'Role',
    'status': 'Status',
  };

  List<Map<String, dynamic>> _filterAndSortUsers(
    List<Map<String, dynamic>> users,
  ) {
    var filtered = users;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = users.where((u) {
        final username = (u['username'] as String).toLowerCase();
        final role = u['role'] as Map<String, dynamic>?;
        final roleName = (role?['rolename'] as String? ?? '').toLowerCase();
        final staff = u['staff'] as Map<String, dynamic>?;
        final guardian = u['guardian'] as Map<String, dynamic>?;

        if (username.contains(query) || roleName.contains(query)) return true;

        if (staff != null) {
          final name = '${staff['firstname']} ${staff['lastname']}'
              .toLowerCase();
          final email = (staff['email'] as String? ?? '').toLowerCase();
          final empNum = (staff['employeenumber'] as String? ?? '')
              .toLowerCase();
          if (name.contains(query) ||
              email.contains(query) ||
              empNum.contains(query)) {
            return true;
          }
        }

        if (guardian != null) {
          final name = '${guardian['firstname']} ${guardian['lastname']}'
              .toLowerCase();
          final email = (guardian['email'] as String? ?? '').toLowerCase();
          if (name.contains(query) || email.contains(query)) return true;
        }

        return false;
      }).toList();
    }

    if (_statusFilter != 'ALL') {
      final wantActive = _statusFilter == 'ACTIVE';
      filtered = filtered
          .where((u) => (u['isactive'] as bool) == wantActive)
          .toList();
    }

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = _getDisplayName(a).compareTo(_getDisplayName(b));
          break;
        case 'role':
          final aRole = a['role'] as Map<String, dynamic>?;
          final bRole = b['role'] as Map<String, dynamic>?;
          comparison = (aRole?['rolename'] as String? ?? '').compareTo(
            bRole?['rolename'] as String? ?? '',
          );
          break;
        case 'status':
          final aActive = a['isactive'] as bool;
          final bActive = b['isactive'] as bool;
          comparison = aActive == bActive ? 0 : (aActive ? -1 : 1);
          break;
        case 'date':
        default:
          comparison = DateTime.parse(
            a['createdat'] as String,
          ).compareTo(DateTime.parse(b['createdat'] as String));
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  String _getDisplayName(Map<String, dynamic> u) {
    final staff = u['staff'] as Map<String, dynamic>?;
    final guardian = u['guardian'] as Map<String, dynamic>?;
    if (staff != null) {
      return '${staff['firstname']} ${staff['lastname']}';
    } else if (guardian != null) {
      return '${guardian['firstname']} ${guardian['lastname']}';
    }
    return u['username'] as String;
  }

  static String _roleLabel(String role) => role
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_allUsersProvider);

    return UiPage(
      children: [
        PageHead(
          kicker: 'Users & Access',
          title: 'User Accounts',
          subtitle: 'Account status, role, last login and security actions.',
          actions: [
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_allUsersProvider),
            ),
            Can(
              permission: 'users:create',
              child: UiButton.secondary(
                'Add Staff',
                icon: Icons.badge_outlined,
                onPressed: () async {
                  await context.push<bool>('/users/staff/new');
                  if (context.mounted) ref.invalidate(_allUsersProvider);
                },
              ),
            ),
            Can(
              permission: 'users:create',
              child: UiButton(
                'Add User',
                icon: Icons.person_add_alt,
                onPressed: () async {
                  await context.push<bool>('/admin/users/create');
                  // Always refresh after returning - user may have been created.
                  if (context.mounted) ref.invalidate(_allUsersProvider);
                },
              ),
            ),
          ],
        ),
        UiToolbar(
          searchHint: 'Search by name, email, role or employee number',
          onSearch: (value) => setState(() {
            _searchQuery = value.trim();
            _currentPage = 0;
          }),
          trailing: [
            for (final (value, label) in const [
              ('ALL', 'All'),
              ('ACTIVE', 'Active'),
              ('INACTIVE', 'Inactive'),
            ])
              FilterChipBox(
                label,
                selected: _statusFilter == value,
                onTap: () => setState(() {
                  _statusFilter = value;
                  _currentPage = 0;
                }),
              ),
            PopupMenuButton<String>(
              tooltip: 'Sort users',
              onSelected: (value) => setState(() {
                if (value == '_direction') {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                }
              }),
              itemBuilder: (_) => [
                for (final entry in _sortLabels.entries)
                  CheckedPopupMenuItem(
                    value: entry.key,
                    checked: entry.key == _sortBy,
                    child: Text(entry.value),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: '_direction',
                  child: Text(
                    _sortAscending
                        ? 'Switch to descending'
                        : 'Switch to ascending',
                  ),
                ),
              ],
              child: IgnorePointer(
                child: FilterChipBox(
                  'Sort: ${_sortLabels[_sortBy]} ${_sortAscending ? '↑' : '↓'}',
                ),
              ),
            ),
          ],
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading user accounts…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(_allUsersProvider),
          ),
          data: (users) {
            if (users.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.people_outline,
                  title: 'No users found',
                  message: 'Create the first user account.',
                ),
              );
            }
            final filteredUsers = _filterAndSortUsers(users);
            if (filteredUsers.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.search_off,
                  title: 'No matching accounts',
                  message: 'Try a different search or status filter.',
                ),
              );
            }
            final pageCount = (filteredUsers.length / _pageSize).ceil();
            final page = _currentPage.clamp(0, pageCount - 1);
            final visible = PagerBar.slice(filteredUsers, page, _pageSize);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTableCard(
                  columns: const [
                    UiColumn('User', flex: 18),
                    UiColumn('Type', flex: 11, hideOnPhone: true),
                    UiColumn('Role', flex: 11),
                    UiColumn('Status', flex: 12),
                    UiColumn('', width: 76),
                  ],
                  rows: [for (final u in visible) _row(context, u)],
                ),
                PagerBar(
                  total: filteredUsers.length,
                  page: page,
                  pageSize: _pageSize,
                  onPage: (p) => setState(() => _currentPage = p),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  UiTableRow _row(BuildContext context, Map<String, dynamic> u) {
    final role = u['role'] as Map<String, dynamic>?;
    final staff = u['staff'] as Map<String, dynamic>?;
    final guardian = u['guardian'] as Map<String, dynamic>?;
    final isActive = u['isactive'] as bool;
    final mustChange = u['mustchangepassword'] as bool;
    final roleName = role?['rolename'] as String? ?? 'No Role';
    final currentUser = ref.read(authProvider).user;
    final canDeactivate =
        currentUser?.roleName.toUpperCase() == 'SUPER_USER' &&
        currentUser?.userId != u['userid'];

    String displayName = u['username'] as String;
    String? email;
    String typeLabel = 'Account';

    if (staff != null) {
      displayName = '${staff['firstname']} ${staff['lastname']}';
      email = staff['email'] as String?;
      typeLabel = 'Staff · EMP# ${staff['employeenumber']}';
    } else if (guardian != null) {
      displayName = '${guardian['firstname']} ${guardian['lastname']}';
      email = guardian['email'] as String?;
      typeLabel = 'Guardian';
    }

    return UiTableRow(
      [
        PersonCell(displayName, subtitle: email),
        UiCellText(typeLabel),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusPill(_roleLabel(roleName)),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            isActive
                ? const StatusPill('Active', tone: StatusTone.success)
                : const StatusPill('Inactive', tone: StatusTone.danger),
            if (mustChange)
              const StatusPill('Password change due', tone: StatusTone.warning),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (canDeactivate && isActive)
              IconButton(
                icon: const Icon(
                  Icons.person_off_outlined,
                  color: Colors.red,
                  size: 20,
                ),
                tooltip: 'Deactivate user',
                onPressed: () => _confirmDeactivation(context, u, displayName),
              ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ],
      onTap: () async {
        await context.push('/admin/users/${u['userid']}');
        if (context.mounted) ref.invalidate(_allUsersProvider);
      },
    );
  }

  Future<void> _confirmDeactivation(
    BuildContext context,
    Map<String, dynamic> user,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('Deactivate user?'),
        content: Text(
          '$displayName will no longer be able to sign in. Their school records will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(userRepositoryProvider)
          .deactivateUserSecure(user['userid'] as String);
      ref.invalidate(_allUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName was deactivated.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not deactivate user: $error')),
        );
      }
    }
  }
}
