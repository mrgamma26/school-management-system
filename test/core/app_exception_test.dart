import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/errors/app_exception.dart';

void main() {
  group('friendlyError', () {
    test('returns message from AppException subclasses', () {
      expect(friendlyError(const ForbiddenException()), contains('permission'));
    });

    test('handles duplicate/unique constraint message', () {
      final result = friendlyError(Exception('duplicate key value'));
      expect(result, contains('already exists'));
    });

    test('handles permission/42501 message', () {
      final result = friendlyError(Exception('42501 insufficient privilege'));
      expect(result, contains('permission'));
    });

    test('returns generic message for unknown errors', () {
      final result = friendlyError(Exception('some random error'));
      expect(result, contains('Something went wrong'));
    });
  });
}
