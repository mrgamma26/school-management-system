import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/supabase_client.dart';
import '../../domain/models/app_user.dart';

/// Handles authentication against Supabase Auth and loads the
/// corresponding [AppUser] profile from [systemuser] + [role].
class AuthRepository {
  /// Signs the user in, loads their profile and validates their account status.
  ///
  /// Throws [AuthException] on auth failure.
  /// Throws [AuthException] when the account is inactive.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Authentication failed.');
    }

    final row = await supabase
        .from('systemuser')
        .select(
          'userid, username, roleid, mustchangepassword, isactive, role(rolename)',
        )
        .eq('userid', user.id)
        .single();

    final appUser = AppUser.fromJson(row);

    if (!appUser.isActive) {
      await supabase.auth.signOut();
      throw const AuthException('This account is inactive.');
    }

    return appUser;
  }

  /// Signs the current user out of Supabase Auth.
  Future<void> signOut() => supabase.auth.signOut();

  /// Returns the active Supabase [Session], or null when not signed in.
  Session? get currentSession => supabase.auth.currentSession;

  /// Changes the password for the currently authenticated user.
  Future<void> changePassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }
}
