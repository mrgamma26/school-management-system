import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';

/// Shows [child] only when the current user's role grants [permission].
class Can extends ConsumerWidget {
  final String permission;
  final Widget child;
  final Widget fallback;

  const Can({
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    return permissions.when(
      data: (granted) => granted.contains(permission) ? child : fallback,
      loading: () => fallback,
      error: (_, _) => fallback,
    );
  }
}
