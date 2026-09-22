import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/models/staff.dart';
import '../../data/repositories/user_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'staff_form_page.dart';

final _staffListProvider = FutureProvider<List<Staff>>((ref) {
  return UserRepository().listStaff();
});

class StaffListPage extends ConsumerStatefulWidget {
  const StaffListPage({super.key});

  @override
  ConsumerState<StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends ConsumerState<StaffListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_staffListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_staffListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const StaffFormPage()),
          );
          if (mounted) ref.invalidate(_staffListProvider);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or employee number...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingState(message: 'Loading staff...'),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(_staffListProvider),
              ),
              data: (staff) {
                final filtered = _query.isEmpty
                    ? staff
                    : staff
                          .where(
                            (s) =>
                                s.fullName.toLowerCase().contains(_query) ||
                                s.employeeNumber.toLowerCase().contains(_query),
                          )
                          .toList();

                if (staff.isEmpty) {
                  return EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'No staff members yet',
                    subtitle: 'Add staff members to get started.',
                    action: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StaffFormPage(),
                          ),
                        );
                        if (mounted) ref.invalidate(_staffListProvider);
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Staff'),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No results for "$_query"',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.roleTeacher.withValues(
                            alpha: 0.15,
                          ),
                          child: Text(
                            s.firstName[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.roleTeacher,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          s.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMP# ${s.employeeNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              s.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: s.email != null,
                        onTap: () async {
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StaffFormPage(existing: s),
                            ),
                          );
                          if (mounted) ref.invalidate(_staffListProvider);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
