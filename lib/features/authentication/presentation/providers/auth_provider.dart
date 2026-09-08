import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;

  const AuthState({this.isLoading = false, this.errorMessage});

  AuthState copyWith({bool? isLoading, String? errorMessage}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    return const AuthState();
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.signIn(email: email, password: password);

      state = state.copyWith(isLoading: false);

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());

      return false;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
