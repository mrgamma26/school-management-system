import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/guardian.dart';
import '../../data/repositories/user_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

final _guardianListProvider = FutureProvider<List<Guardian>>((ref) {
  return UserRepository().listGuardians();
});

/// Displays guardians created during student registration and supports edits.
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
    final canEdit = ref
        .watch(permissionsProvider)
        .maybeWhen(
          data: (permissions) => permissions.contains('guardians:write'),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardians'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_guardianListProvider),
          ),
        ],
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
              error: (e, _) => Center(child: Text(friendlyError(e))),
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
                      onTap: canEdit
                          ? () async {
                              await context.push<bool>(
                                '/users/guardians/${g.guardianId}/edit',
                                extra: g,
                              );
                              if (mounted) {
                                ref.invalidate(_guardianListProvider);
                              }
                            }
                          : null,
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
