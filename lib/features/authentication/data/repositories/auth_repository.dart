import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/models/app_user.dart';

/// Maps Supabase/auth errors to [AppException] subtypes.
AppException _mapException(Object error) {
  final text = error.toString();

  // Auth errors
  if (text.contains('Invalid login credentials')) {
    return UnauthorisedException('Incorrect email or password.');
  }
  if (text.contains('Email not confirmed')) {
    return UnauthorisedException(
      'Confirm your email address before signing in.',
    );
  }
  if (text.contains('inactive')) {
    return UnauthorisedException('This account is inactive.');
  }

  // Profile not found → NotFoundException
  if (text.contains('0 rows') ||
      text.contains('PGRST116') ||
      text.contains('single()') ||
      text.contains('no rows')) {
    return NotFoundException(
      'Account profile not found. Ask your system administrator to '
      'create a system profile for your account.',
    );
  }

  // Permission/auth errors → ForbiddenException
  if (text.contains('permission') ||
      text.contains('42501') ||
      text.contains('denied')) {
    return ForbiddenException(
      'You do not have permission to perform this action.',
    );
  }

  // Network errors → NetworkException
  if (text.contains('network') ||
      text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset')) {
    return NetworkException(
      'Network error. Check your connection and try again.',
    );
  }

  // Server/database errors → ServerException
  return ServerException('Something went wrong. Please try again.');
}

class AuthRepository {
  /// Signs the user in, loads their profile and validates their account status.
  ///
  /// Throws [AppException] on auth failure or validation error.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw UnauthorisedException('Authentication failed.');
      }

      return await loadCurrentUser();
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Loads the application profile for the currently authenticated user.
  Future<AppUser> loadCurrentUser() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw UnauthorisedException('Authentication session not found.');
      }

      final row = await supabase
          .from('systemuser')
          .select(
            'userid, username, roleid, mustchangepassword, isactive, role:role!fk_systemuser_role(rolename), user_roles:user_roles!user_roles_user_id_fkey(role_id, role:role_id(rolename))',
          )
          .eq('userid', user.id)
          .single();

      final appUser = AppUser.fromJson(row);

      if (!appUser.isActive) {
        await supabase.auth.signOut();
        throw UnauthorisedException('This account is inactive.');
      }

      return appUser;
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Signs the current user out of Supabase Auth.
  Future<void> signOut() => supabase.auth.signOut();

  /// Returns the active Supabase [Session], or null when not signed in.
  Session? get currentSession => supabase.auth.currentSession;

  /// Changes the password for the currently authenticated user.
  Future<void> changePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      await supabase.rpc('complete_current_user_password_change');
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Loads all permissions granted to a specific [roleId].
  /// Returns a set of permission names (e.g., {'users:write', 'grades:read'}).
  Future<Set<String>> loadPermissionsForRole(String roleId) async {
    try {
      final rows = await supabase
          .from('rolepermission')
          .select('permissionname')
          .eq('roleid', roleId);
      return (rows as List)
          .map(
            (row) => (row as Map<String, dynamic>)['permissionname'] as String,
          )
          .toSet();
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }
}
