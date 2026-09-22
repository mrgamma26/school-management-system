import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/models/guardian.dart';
import '../../data/repositories/user_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'guardian_form_page.dart';

final _guardianListProvider = FutureProvider<List<Guardian>>((ref) {
  return UserRepository().listGuardians();
});

/// Displays all guardians with search and navigation to the form.
class GuardianListPage extends ConsumerStatefulWidget {
  const GuardianListPage({super.key});

  @override
  ConsumerState<GuardianListPage> createState() => _GuardianListPageState();
}

class _GuardianListPageState extends ConsumerState<GuardianListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_guardianListProvider);
    final role = ref.watch(authProvider).user?.roleName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardians'),
        actions: [
          HomeButton(roleName: role),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_guardianListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const GuardianFormPage()),
          );
          if (mounted) ref.invalidate(_guardianListProvider);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Guardian'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (guardians) {
                final filtered = _query.isEmpty
                    ? guardians
                    : guardians
                          .where(
                            (g) =>
                                g.fullName.toLowerCase().contains(_query) ||
                                (g.email?.toLowerCase().contains(_query) ??
                                    false),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No guardians found.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final g = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(g.firstName[0].toUpperCase()),
                      ),
                      title: Text(g.fullName),
                      subtitle: Text(
                        '${g.email}${g.phoneNumber != null ? ' - ${g.phoneNumber}' : ''}',
                      ),
                      onTap: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GuardianFormPage(existing: g),
                          ),
                        );
                        if (mounted) ref.invalidate(_guardianListProvider);
                      },
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
