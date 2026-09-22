import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../users/data/repositories/user_repository.dart';
import 'create_user_page.dart';
import 'user_details_page.dart';

// FIX 3: Enhanced with search, sort, and pagination

final _allUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final rows = await supabase
          .from('systemuser')
          .select('''
        userid, username, mustchangepassword, isactive, createdat,
        role(rolename),
        staff(firstname, lastname, email, employeenumber),
        guardian(firstname, lastname, email)
      ''')
          .order('createdat', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    });

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  // FIX 3: Search, sort, and pagination state
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'date'; // 'date', 'name', 'role', 'status'
  bool _sortAscending = false;
  int _currentPage = 0;
  final int _itemsPerPage = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterAndSortUsers(
    List<Map<String, dynamic>> users,
  ) {
    var filtered = users;

    // Apply search filter
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

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          final aName = _getDisplayName(a);
          final bName = _getDisplayName(b);
          comparison = aName.compareTo(bName);
          break;
        case 'role':
          final aRole = a['role'] as Map<String, dynamic>?;
          final bRole = b['role'] as Map<String, dynamic>?;
          final aRoleName = aRole?['rolename'] as String? ?? '';
          final bRoleName = bRole?['rolename'] as String? ?? '';
          comparison = aRoleName.compareTo(bRoleName);
          break;
        case 'status':
          final aActive = a['isactive'] as bool;
          final bActive = b['isactive'] as bool;
          comparison = aActive == bActive ? 0 : (aActive ? -1 : 1);
          break;
        case 'date':
        default:
          final aDate = DateTime.parse(a['createdat'] as String);
          final bDate = DateTime.parse(b['createdat'] as String);
          comparison = aDate.compareTo(bDate);
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_allUsersProvider);
    final role = ref.watch(authProvider).user?.roleName ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          HomeButton(roleName: role),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_allUsersProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateUserPage()),
          );
          // Always refresh after returning - user may have been created.
          if (context.mounted) ref.invalidate(_allUsersProvider);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading users...'),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_allUsersProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No users found',
              subtitle: 'Create the first user account.',
            );
          }

          // Apply filters and sorting
          final filteredUsers = _filterAndSortUsers(users);

          // Calculate pagination
          final totalPages = (filteredUsers.length / _itemsPerPage).ceil();
          if (_currentPage >= totalPages && totalPages > 0) {
            _currentPage = totalPages - 1;
          }
          final startIndex = _currentPage * _itemsPerPage;
          final endIndex = (startIndex + _itemsPerPage).clamp(
            0,
            filteredUsers.length,
          );
          final paginatedUsers = filteredUsers.sublist(startIndex, endIndex);

          return Column(
            children: [
              // FIX 3: Search and sort controls
              _buildControls(cs, filteredUsers.length, totalPages),

              // User list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: paginatedUsers.length,
                  itemBuilder: (_, i) =>
                      _buildUserCard(context, cs, paginatedUsers[i], ref),
                ),
              ),

              // FIX 3: Pagination controls
              if (totalPages > 1) _buildPagination(totalPages),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls(ColorScheme cs, int totalCount, int totalPages) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, email, role, or employee number...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _searchQuery = '';
                          _currentPage = 0;
                        });
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _currentPage = 0; // Reset to first page on search
              });
            },
          ),
          const SizedBox(height: 12),

          // Sort and results info
          Row(
            children: [
              // Sort dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    prefixIcon: Icon(Icons.sort),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'date',
                      child: Text('Date Created'),
                    ),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'role', child: Text('Role')),
                    DropdownMenuItem(value: 'status', child: Text('Status')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sortBy = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Sort direction toggle
              IconButton(
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                tooltip: _sortAscending ? 'Ascending' : 'Descending',
                onPressed: () {
                  setState(() => _sortAscending = !_sortAscending);
                },
              ),
              const SizedBox(width: 8),

              // Results count
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalCount user${totalCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            'Page ${_currentPage + 1} of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    ColorScheme cs,
    Map<String, dynamic> u,
    WidgetRef ref,
  ) {
    final role = u['role'] as Map<String, dynamic>?;
    final staff = u['staff'] as Map<String, dynamic>?;
    final guardian = u['guardian'] as Map<String, dynamic>?;
    final isActive = u['isactive'] as bool;
    final mustChange = u['mustchangepassword'] as bool;
    final roleName = role?['rolename'] as String? ?? 'No Role';

    String displayName = u['username'] as String;
    String? email;
    String? typeLabel;
    IconData typeIcon = Icons.person;

    if (staff != null) {
      displayName = '${staff['firstname']} ${staff['lastname']}';
      email = staff['email'] as String?;
      typeLabel = 'Staff - EMP# ${staff['employeenumber']}';
      typeIcon = Icons.badge;
    } else if (guardian != null) {
      displayName = '${guardian['firstname']} ${guardian['lastname']}';
      email = guardian['email'] as String?;
      typeLabel = 'Guardian';
      typeIcon = Icons.family_restroom;
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? AppColors.forRole(roleName).withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          child: Icon(
            typeIcon,
            color: isActive ? AppColors.forRole(roleName) : Colors.grey,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (!isActive) ...[
              const SizedBox(width: 6),
              const StatusBadge('INACTIVE'),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RoleBadge(roleName),
                if (typeLabel != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
            if (email != null)
              Text(
                email,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            if (mustChange)
              Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 12,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Must change password',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailsPage(userId: u['userid'] as String),
            ),
          );
          if (context.mounted) ref.invalidate(_allUsersProvider);
        },
      ),
    );
  }
}
