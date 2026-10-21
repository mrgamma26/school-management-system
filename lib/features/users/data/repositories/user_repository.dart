import '../../../../core/database/supabase_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/rpc_error.dart';
import '../../domain/models/staff.dart';
import '../../domain/models/guardian.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, FunctionsFetchException;

/// Maximum rows returned by list methods in a single fetch.
const int kUserPageSize = 1000;

/// Maps Supabase/database errors to [AppException] subtypes.
AppException _mapException(Object error) {
  final text = error.toString();

  // Permission/auth errors → ForbiddenException
  if (text.contains('permission') ||
      text.contains('42501') ||
      text.contains('denied')) {
    return ForbiddenException(
      'You do not have permission to perform this action.',
    );
  }

  // Not found errors → NotFoundException
  if (text.contains('0 rows') ||
      text.contains('PGRST116') ||
      text.contains('single()') ||
      text.contains('no rows')) {
    return NotFoundException('Resource not found.');
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

/// Handles staff and guardian data operations.
/// Account creation/deletion goes through the privileged Edge Functions.
class UserRepository {
  // Staff

  /// Returns up to [kUserPageSize] staff records ordered by last name.
  Future<List<Staff>> listStaff({int offset = 0}) async {
    try {
      final rows = await supabase
          .from('staff')
          .select(
            'staffid, userid, employeenumber, firstname, middlename, lastname, gender, email, dateofbirth, nationalid, phonenumber, alternativephone, physicaladdress, profilepicturepath, jobtitle, department, employmenttype, employmentstatus, employmentstartdate, professionalqualifications, highestacademicqualification, yearsofexperience, emergencycontactname, emergencycontactphone, emergencycontactrelationship',
          )
          .order('lastname')
          .range(offset, offset + kUserPageSize - 1);
      return rows.map((r) => Staff.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns a single staff record by [staffId].
  Future<Staff> getStaff(String staffId) async {
    try {
      final row = await supabase
          .from('staff')
          .select(
            'staffid, userid, employeenumber, firstname, middlename, lastname, gender, email, dateofbirth, nationalid, phonenumber, alternativephone, physicaladdress, profilepicturepath, jobtitle, department, employmenttype, employmentstatus, employmentstartdate, professionalqualifications, highestacademicqualification, yearsofexperience, emergencycontactname, emergencycontactphone, emergencycontactrelationship',
          )
          .eq('staffid', staffId)
          .single();
      return Staff.fromJson(row);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Updates permitted profile fields for a staff member.
  Future<void> updateStaff(String staffId, Map<String, dynamic> data) async {
    try {
      await supabase.from('staff').update(data).eq('staffid', staffId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Deactivates a staff account (soft-delete).
  /// Throws [AppException] if no rows were updated (user not found or RLS denied).
  Future<void> deactivateUser(String userId) async {
    try {
      final result = await supabase
          .from('systemuser')
          .update({'isactive': false})
          .eq('userid', userId)
          .select();

      if (result.isEmpty) {
        throw NotFoundException(
          'Failed to deactivate user. User not found or insufficient permissions.',
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Soft-deactivates an account through the privileged Edge Function.
  /// The server independently verifies that the caller is a Super User.
  Future<void> deactivateUserSecure(String targetUserId) async {
    try {
      final response = await supabase.functions.invoke(
        'delete-user',
        body: {'targetUserId': targetUserId},
      );
      if (response.status != 200) {
        final message =
            (response.data as Map<String, dynamic>?)?['error'] ??
            'Could not deactivate the user.';
        throw ServerException(message.toString());
      }
    } on FunctionsFetchException {
      throw ServerException(
        'Could not connect to the user-deactivation function. Confirm it is deployed.',
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map
          ? details['error'] ?? details['message']
          : details;
      throw ServerException(
        message?.toString() ??
            e.reasonPhrase ??
            'Could not deactivate the user.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Reactivates a deactivated user account.
  /// Throws [AppException] if no rows were updated (user not found or RLS denied).
  Future<void> reactivateUser(String userId) async {
    try {
      final result = await supabase
          .from('systemuser')
          .update({'isactive': true})
          .eq('userid', userId)
          .select();

      if (result.isEmpty) {
        throw NotFoundException(
          'Failed to reactivate user. User not found or insufficient permissions.',
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Creates a new user through the privileged Edge Function.
  /// Throws [AppException] on any failure.
  Future<String> createUser(Map<String, dynamic> payload) async {
    try {
      late final dynamic response;
      try {
        response = await supabase.functions.invoke(
          'create-user',
          body: payload,
        );
      } on FunctionsFetchException {
        throw ServerException(
          'Could not connect to the create-user function. Check your internet '
          'connection and confirm that the function is deployed.',
        );
      } on FunctionException catch (e) {
        final details = e.details;
        final message = details is Map
            ? (details['error'] ?? details['message'] ?? details['code'])
            : details;
        throw ServerException(
          message?.toString().trim().isNotEmpty == true
              ? 'create-user failed (${e.status}): $message'
              : 'create-user failed (${e.status}): '
                    '${e.reasonPhrase ?? 'Unknown function error.'}',
        );
      }

      if (response.status != 200) {
        final message =
            (response.data as Map<String, dynamic>?)?['error'] ??
            response.data.toString();
        throw ServerException(message);
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['userId'] == null) {
        throw ServerException('Edge function returned no userId.');
      }
      return data['userId'] as String;
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Resets a user's password through the privileged Edge Function.
  Future<void> resetPassword({
    required String targetUserId,
    required String newPassword,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'reset-user-password',
        body: {'targetUserId': targetUserId, 'newPassword': newPassword},
      );
      if (response.status != 200) {
        final message =
            (response.data as Map<String, dynamic>?)?['error'] ??
            response.data.toString();
        throw ServerException(message);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  // Guardian

  /// Returns up to [kUserPageSize] guardian records ordered by last name.
  Future<List<Guardian>> listGuardians({int offset = 0}) async {
    try {
      final rows = await supabase
          .from('guardian')
          .select(
            'guardianid, userid, firstname, middlename, lastname, gender, phonenumber, physicaladdress, email',
          )
          .order('lastname')
          .range(offset, offset + kUserPageSize - 1);
      return rows.map((r) => Guardian.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns a single guardian record by [guardianId].
  Future<Guardian> getGuardian(String guardianId) async {
    try {
      final row = await supabase
          .from('guardian')
          .select(
            'guardianid, userid, firstname, middlename, lastname, gender, phonenumber, physicaladdress, email',
          )
          .eq('guardianid', guardianId)
          .single();
      return Guardian.fromJson(row);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns the guardian row for a given auth [userId].
  Future<Map<String, dynamic>> getGuardianByUserId(String userId) async {
    try {
      final row = await supabase
          .from('guardian')
          .select('guardianid, userid, firstname, lastname, email')
          .eq('userid', userId)
          .single();
      return Map<String, dynamic>.from(row);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Updates permitted profile fields for a guardian.
  Future<void> updateGuardian(
    String guardianId,
    Map<String, dynamic> data,
  ) async {
    try {
      await supabase.from('guardian').update(data).eq('guardianid', guardianId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  // Roles (read-only for UI dropdowns)

  /// Returns all roles for use in account-creation forms.
  Future<List<Map<String, dynamic>>> listRoles() async {
    try {
      return await supabase
          .from('role')
          .select('roleid, rolename')
          .order('rolename');
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Grants [roleId] as a secondary (non-primary) role in `user_roles`.
  ///
  /// Only the Teacher + Head Teacher pair is accepted by the database trigger
  /// `validate_user_role_pair`, and `user_roles_manage` RLS limits writes to
  /// Super Users and Administrators.
  Future<void> addSecondaryRole({
    required String userId,
    required String roleId,
  }) async {
    try {
      await supabase.from('user_roles').insert({
        'user_id': userId,
        'role_id': roleId,
        'is_primary': false,
      });
    } catch (e) {
      if (e.toString().contains('dual-role')) {
        throw ServerException(
          'Only the Teacher and Head Teacher dual-role combination is permitted.',
        );
      }
      throw _mapException(e);
    }
  }

  /// The `staff.staffid` for an auth user, or null when no staff row exists.
  Future<String?> staffIdForUser(String userId) async {
    try {
      final row = await supabase
          .from('staff')
          .select('staffid')
          .eq('userid', userId)
          .maybeSingle();
      return row?['staffid'] as String?;
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Every subject in the catalogue, for the "subjects they teach" picker.
  Future<List<Map<String, dynamic>>> subjectOptions() async {
    try {
      final rows = await supabase
          .from('subject')
          .select('subjectid, subjectname')
          .order('subjectname');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// The subject ids a staff member is marked as teaching.
  Future<Set<String>> staffSubjectIds(String staffId) async {
    try {
      final rows = await supabase
          .from('staff_subjects')
          .select('subject_id')
          .eq('staff_id', staffId);
      return {
        for (final row in rows as List) (row as Map)['subject_id'] as String,
      };
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Replaces the subjects a staff member is marked as teaching. The database
  /// refuses to un-mark a subject the teacher currently teaches in a class.
  Future<void> setStaffSubjects(String staffId, Set<String> subjectIds) async {
    try {
      await supabase.rpc(
        'set_staff_subjects',
        params: {'p_staff_id': staffId, 'p_subject_ids': subjectIds.toList()},
      );
    } catch (e) {
      throw ServerException(rpcErrorMessage(e));
    }
  }

  /// Lists all system users with their role and staff/guardian details.
  /// Returns a list of combined records (systemuser + role + staff/guardian data).
  Future<List<Map<String, dynamic>>> listAllSystemUsers() async {
    try {
      final systemUsers = await supabase
          .from('systemuser')
          .select(
            'userid, username, role:role!fk_systemuser_role(rolename), mustchangepassword, isactive, createdat',
          )
          .order('createdat', ascending: false);

      final staffRows = await supabase
          .from('staff')
          .select('userid, firstname, lastname, email, employeenumber');

      final guardianRows = await supabase
          .from('guardian')
          .select('userid, firstname, lastname, email');

      // Build lookup maps
      final staffByUserId = <String, Map<String, dynamic>>{
        for (final row in staffRows as List)
          row['userid'] as String: Map<String, dynamic>.from(row),
      };
      final guardianByUserId = <String, Map<String, dynamic>>{
        for (final row in guardianRows as List)
          row['userid'] as String: Map<String, dynamic>.from(row),
      };

      // Combine records
      return (systemUsers as List).map((row) {
        final user = Map<String, dynamic>.from(row);
        final userId = user['userid'] as String;
        user['staff'] = staffByUserId[userId];
        user['guardian'] = guardianByUserId[userId];
        return user;
      }).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// FIX 4: Changes a user's role (SUPER_ADMIN only operation).
  /// Throws [AppException] if no rows were updated (user not found or RLS denied).
  Future<void> changeUserRole(String userId, String newRoleId) async {
    try {
      final result = await supabase
          .from('systemuser')
          .update({'roleid': newRoleId})
          .eq('userid', userId)
          .select();

      if (result.isEmpty) {
        throw NotFoundException(
          'Failed to change user role. User not found or insufficient permissions.',
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw _mapException(e);
    }
  }

  /// Gets a single system user with full details (profile + role + staff/guardian).
  Future<Map<String, dynamic>> getSystemUserWithDetails(String userId) async {
    try {
      final row = await supabase
          .from('systemuser')
          .select('''
            userid, username, mustchangepassword, isactive, createdat, updatedat,
            role:role!fk_systemuser_role(roleid, rolename, description),
            staff(staffid, firstname, lastname, email, employeenumber, gender),
            guardian(guardianid, firstname, lastname, email, phonenumber, gender)
          ''')
          .eq('userid', userId)
          .single();
      return Map<String, dynamic>.from(row);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Gets role details including its assigned permissions.
  Future<Map<String, dynamic>> getRoleWithPermissions(String roleId) async {
    try {
      final role = await supabase
          .from('role')
          .select(
            'roleid, rolename, description, rolepermission(permissionid, permissionname)',
          )
          .eq('roleid', roleId)
          .single();
      return Map<String, dynamic>.from(role);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Adds permissions to a role.
  Future<void> addPermissionsToRole(
    String roleId,
    List<String> permissionNames,
  ) async {
    try {
      if (permissionNames.isEmpty) return;
      await supabase
          .from('rolepermission')
          .insert(
            permissionNames
                .map((name) => {'roleid': roleId, 'permissionname': name})
                .toList(),
          );
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Removes a permission from a role by permission ID.
  Future<void> removePermissionFromRole(String permissionId) async {
    try {
      await supabase
          .from('rolepermission')
          .delete()
          .eq('permissionid', permissionId);
    } catch (e) {
      throw _mapException(e);
    }
  }
}
