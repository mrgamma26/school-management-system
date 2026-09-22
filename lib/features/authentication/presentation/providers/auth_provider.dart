import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return const AuthState();
  }

  /// Signs the user in and populates [AuthState.user] on success.
  /// Returns `true` on success, `false` on failure.
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendly(e));
      return false;
    }
  }

  /// Signs the user out and resets state.
  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState();
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
      state = state.copyWith(isLoading: false, errorMessage: _friendly(e));
      return false;
    }
  }

  String _friendly(Object error) {
    final text = error.toString();

    if (text.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (text.contains('inactive')) return 'This account is inactive.';
    if (text.contains('network') || text.contains('SocketException')) {
      return 'Network error. Check your connection and try again.';
    }
    // systemuser row missing — auth worked but profile not found
    if (text.contains('contains 0 rows') ||
        text.contains('PGRST116') ||
        text.contains('JSON object requested') ||
        text.contains('single()')) {
      return 'Account profile not found. Ask your system administrator to '
          'create a system profile for your account.';
    }

    // In debug mode show the raw error so you can see exactly what failed.
    assert(() {
      developer.log('Login error', name: 'AuthNotifier', error: error);
      return true;
    }());

    return 'Something went wrong. Please try again.';
  }
}

/// Top-level provider used by widgets and the router.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
