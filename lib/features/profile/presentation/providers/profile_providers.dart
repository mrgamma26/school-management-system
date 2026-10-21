import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../users/data/repositories/user_repository.dart';
import '../../../users/domain/models/staff.dart';

/// The signed-in user's own staff record, or null when they have none
/// (guardians, or a Super User without a staff profile).
///
/// Read-only: uses the existing [UserRepository] lookups.
final myStaffProfileProvider = FutureProvider.autoDispose<Staff?>((ref) async {
  final user = ref.watch(authProvider).user;
  // Guardians have no staff record.
  if (user == null || schoolRole(user.roleName) == 'GUARDIAN') return null;
  final repository = UserRepository();
  final staffId = await repository.staffIdForUser(user.userId);
  if (staffId == null) return null;
  return repository.getStaff(staffId);
});
