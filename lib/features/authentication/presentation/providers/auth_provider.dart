import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/app_user.dart';

/// Exposes a singleton [AuthRepository] to the widget tree.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

/// Immutable state snapshot for authentication.
class AuthState {
  final bool isLoading;
  final AppUser? user;
  final String? errorMessage;

  const AuthState({this.isLoading = false, this.user, this.errorMessage});

  AuthState copyWith({
    bool? isLoading,
    AppUser? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Manages sign-in, sign-out and change-password flows.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;

  @override
  AuthState build() {
    _repo = ref.watch(authRepositoryProvider);
    final hasSession = _repo.currentSession != null;

    final authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery ||
          data.event == AuthChangeEvent.signedIn) {
        unawaited(_restoreSession());
      } else if (data.event == AuthChangeEvent.signedOut) {
        state = const AuthState();
      }
    });
    ref.onDispose(authSubscription.cancel);

    if (hasSession) {
      unawaited(_restoreSession());
    }

    return AuthState(isLoading: hasSession);
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _repo.loadCurrentUser();
      state = state.copyWith(isLoading: false, user: user, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        errorMessage: friendlyError(e),
      );
    }
  }

  /// Signs the user in and populates [AuthState.user] on success.
  /// Returns `true` on success, `false` on failure.
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false, user: user);
      ref.invalidate(permissionsProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  /// Signs the user out and resets state.
  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState();
    ref.invalidate(permissionsProvider);
  }

  /// Changes the password and clears the mustChangePassword flag locally.
  Future<bool> changePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.changePassword(newPassword);
      // Reload user profile to reflect updated mustChangePassword flag.
      if (state.user != null) {
        final updated = AppUser(
          userId: state.user!.userId,
          username: state.user!.username,
          roleId: state.user!.roleId,
          roleName: state.user!.roleName,
          mustChangePassword: false,
          isActive: state.user!.isActive,
        );
        state = state.copyWith(isLoading: false, user: updated);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }
}

/// Top-level provider used by widgets and the router.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Loads the permissions granted to the current user's role.
final permissionsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return <String>{};

  return AuthRepository().loadPermissionsForRole(user.roleId);
});
