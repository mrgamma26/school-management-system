import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';

void main() {
  test('recognises the permitted Teacher and Head Teacher workspaces', () {
    final user = AppUser.fromJson({
      'userid': 'user-1',
      'username': 'dual.role',
      'roleid': 'teacher-role',
      'mustchangepassword': false,
      'isactive': true,
      'role': {'rolename': 'TEACHER'},
      'user_roles': [
        {
          'role_id': 'teacher-role',
          'role': {'rolename': 'TEACHER'},
        },
        {
          'role_id': 'head-role',
          'role': {'rolename': 'HEAD_TEACHER'},
        },
      ],
    });

    expect(user.hasWorkspaceSwitcher, isTrue);
    expect(user.roleIdFor('HEAD_TEACHER'), 'head-role');
  });
}
