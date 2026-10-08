import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/core/errors/app_exception.dart';

void main() {
  group('AppException subclasses', () {
    test('each subclass is an AppException', () {
      expect(const UnauthorisedException(), isA<AppException>());
      expect(const ForbiddenException(), isA<AppException>());
      expect(const NotFoundException(), isA<AppException>());
      expect(const NetworkException(), isA<AppException>());
      expect(const ServerException(), isA<AppException>());
    });

    test('each subclass is an Exception', () {
      expect(const ForbiddenException(), isA<Exception>());
      expect(const NetworkException(), isA<Exception>());
    });

    test('default messages are non-empty', () {
      expect(const UnauthorisedException().message, isNotEmpty);
      expect(const ForbiddenException().message, isNotEmpty);
      expect(const NotFoundException().message, isNotEmpty);
      expect(const NetworkException().message, isNotEmpty);
      expect(const ServerException().message, isNotEmpty);
    });

    test('custom message overrides the default', () {
      const e = UnauthorisedException('Token expired.');
      expect(e.message, 'Token expired.');
    });

    test('ValidationException stores field errors', () {
      const e = ValidationException(
        'Invalid input.',
        fieldErrors: {'email': 'Not a valid email address.'},
      );
      expect(e.message, 'Invalid input.');
      expect(e.fieldErrors?['email'], 'Not a valid email address.');
    });

    test('ValidationException fieldErrors can be null', () {
      const e = ValidationException('Something is wrong.');
      expect(e.fieldErrors, isNull);
    });

    test('toString returns the message', () {
      const e = ForbiddenException('Access denied.');
      expect(e.toString(), 'Access denied.');
    });
  });

  group('friendlyError', () {
    test('returns message from AppException subclasses', () {
      expect(friendlyError(const ForbiddenException()), contains('permission'));
    });

    test('handles duplicate/unique constraint message', () {
      expect(
        friendlyError(Exception('duplicate key value')),
        contains('already exists'),
      );
    });

    test('handles permission/42501 message', () {
      expect(
        friendlyError(Exception('42501 insufficient privilege')),
        contains('permission'),
      );
    });

    test('handles SocketException message', () {
      expect(
        friendlyError(Exception('SocketException connection refused')),
        contains('Network error'),
      );
    });

    test('returns generic message for unknown errors', () {
      expect(
        friendlyError(Exception('some random error')),
        contains('Something went wrong'),
      );
    });

    test('NetworkException gives network message via friendlyError', () {
      expect(friendlyError(const NetworkException()), contains('Network'));
    });

    test('NotFoundException gives not-found message', () {
      expect(
        friendlyError(const NotFoundException('Student not found.')),
        'Student not found.',
      );
    });
  });
}
