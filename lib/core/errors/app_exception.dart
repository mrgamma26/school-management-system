/// Base class for all application-level exceptions.
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the user is not authenticated or the session is invalid.
class UnauthorisedException extends AppException {
  const UnauthorisedException([super.message = 'Unauthorised.']);
}

/// Thrown when the authenticated user does not have the required permission.
class ForbiddenException extends AppException {
  const ForbiddenException([
    super.message = 'You do not have permission to perform this action.',
  ]);
}

/// Thrown when a requested resource cannot be found.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Resource not found.']);
}

/// Thrown when input fails validation rules.
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;
  const ValidationException(super.message, {this.fieldErrors});
}

/// Thrown on network connectivity failures.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network error. Check your connection and try again.',
  ]);
}

/// Thrown on unexpected server or database errors.
class ServerException extends AppException {
  const ServerException([
    super.message = 'Something went wrong. Please try again.',
  ]);
}

/// Converts any caught [error] into a user-friendly string.
String friendlyError(Object error) {
  if (error is AppException) return error.message;

  final text = error.toString();
  if (text.contains('duplicate') || text.contains('unique')) {
    return 'That value already exists.';
  }
  if (text.contains('permission') || text.contains('42501')) {
    return 'You do not have permission to perform this action.';
  }
  if (text.contains('network') || text.contains('SocketException')) {
    return 'Network error. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}
