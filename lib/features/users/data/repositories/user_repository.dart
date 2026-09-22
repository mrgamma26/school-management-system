import '../../../../core/database/supabase_client.dart';
import '../../domain/models/staff.dart';
import '../../domain/models/guardian.dart';

/// Handles staff and guardian data operations.
/// Account creation/deletion goes through the privileged Edge Functions.
class UserRepository {
  // Staff

  /// Returns all staff records ordered by last name.
  Future<List<Staff>> listStaff() async {
    final rows = await supabase
        .from('staff')
        .select(
          'staffid, userid, employeenumber, firstname, middlename, lastname, gender, email',
        )
        .order('lastname');
    return rows.map((r) => Staff.fromJson(r)).toList();
  }

  /// Returns a single staff record by [staffId].
  Future<Staff> getStaff(String staffId) async {
    final row = await supabase
        .from('staff')
        .select(
          'staffid, userid, employeenumber, firstname, middlename, lastname, gender, email',
        )
        .eq('staffid', staffId)
        .single();
    return Staff.fromJson(row);
  }

  /// Updates permitted profile fields for a staff member.
  Future<void> updateStaff(String staffId, Map<String, dynamic> data) async {
    await supabase.from('staff').update(data).eq('staffid', staffId);
  }

  /// Deactivates a staff account (soft-delete).
  /// Throws [Exception] if no rows were updated (user not found or RLS denied).
  Future<void> deactivateUser(String userId) async {
    final result = await supabase
        .from('systemuser')
        .update({'isactive': false})
        .eq('userid', userId)
        .select();

    if (result.isEmpty) {
      throw Exception(
        'Failed to deactivate user $userId. '
        'User not found or insufficient permissions.',
      );
    }
  }

  /// Reactivates a deactivated user account.
  /// Throws [Exception] if no rows were updated (user not found or RLS denied).
  Future<void> reactivateUser(String userId) async {
    final result = await supabase
        .from('systemuser')
        .update({'isactive': true})
        .eq('userid', userId)
        .select();

    if (result.isEmpty) {
      throw Exception(
        'Failed to reactivate user $userId. '
        'User not found or insufficient permissions.',
      );
    }
  }

  /// Creates a new user through the privileged Edge Function.
  /// Throws a human-readable [Exception] on any failure.
  Future<String> createUser(Map<String, dynamic> payload) async {
    late final dynamic response;
    try {
      response = await supabase.functions.invoke('create-user', body: payload);
    } catch (e) {
      // status: 0 means the edge function URL was unreachable (not deployed,
      // network error, or CORS). Give a clear message instead of a raw exception.
      throw Exception(
        'Could not reach the create-user function.\n'
        'Make sure the Supabase edge function is deployed:\n'
        '  supabase functions deploy create-user\n\n'
        'Original error: $e',
      );
    }

    if (response.status != 200) {
      final message =
          (response.data as Map<String, dynamic>?)?['error'] ??
          response.data.toString();
      throw Exception(message);
    }

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['userId'] == null) {
      throw Exception('Edge function returned no userId.');
    }
    return data['userId'] as String;
  }

  /// Resets a user's password through the privileged Edge Function.
  Future<void> resetPassword({
    required String targetUserId,
    required String newPassword,
  }) async {
    final response = await supabase.functions.invoke(
      'reset-user-password',
      body: {'targetUserId': targetUserId, 'newPassword': newPassword},
    );
    if (response.status != 200) {
      final message =
          (response.data as Map<String, dynamic>?)?['error'] ??
          response.data.toString();
      throw Exception(message);
    }
  }

  // Guardian

  /// Returns all guardian records ordered by last name.
  Future<List<Guardian>> listGuardians() async {
    final rows = await supabase
        .from('guardian')
        .select(
          'guardianid, userid, firstname, middlename, lastname, gender, phonenumber, physicaladdress, email',
        )
        .order('lastname');
    return rows.map((r) => Guardian.fromJson(r)).toList();
  }

  /// Returns a single guardian record by [guardianId].
  Future<Guardian> getGuardian(String guardianId) async {
    final row = await supabase
        .from('guardian')
        .select(
          'guardianid, userid, firstname, middlename, lastname, gender, phonenumber, physicaladdress, email',
        )
        .eq('guardianid', guardianId)
        .single();
    return Guardian.fromJson(row);
  }

  /// Returns the guardian row for a given auth [userId].
  Future<Map<String, dynamic>> getGuardianByUserId(String userId) async {
    final row = await supabase
        .from('guardian')
        .select('guardianid, userid, firstname, lastname, email')
        .eq('userid', userId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  /// Updates permitted profile fields for a guardian.
  Future<void> updateGuardian(
    String guardianId,
    Map<String, dynamic> data,
  ) async {
    await supabase.from('guardian').update(data).eq('guardianid', guardianId);
  }

  // Roles (read-only for UI dropdowns)

  /// Returns all roles for use in account-creation forms.
  Future<List<Map<String, dynamic>>> listRoles() async {
    return await supabase
        .from('role')
        .select('roleid, rolename')
        .order('rolename');
  }

  /// FIX 4: Changes a user's role (SUPER_ADMIN only operation).
  /// Throws [Exception] if no rows were updated (user not found or RLS denied).
  Future<void> changeUserRole(String userId, String newRoleId) async {
    final result = await supabase
        .from('systemuser')
        .update({'roleid': newRoleId})
        .eq('userid', userId)
        .select();

    if (result.isEmpty) {
      throw Exception(
        'Failed to change user role for $userId. '
        'User not found or insufficient permissions.',
      );
    }
  }
}
