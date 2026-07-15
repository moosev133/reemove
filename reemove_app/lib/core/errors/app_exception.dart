sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

final class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {super.code, super.cause});
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});
}

final class PermissionException extends AppException {
  const PermissionException(super.message, {super.code, super.cause});
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.cause});
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.code, super.cause});
}

final class UnexpectedException extends AppException {
  const UnexpectedException(super.message, {super.code, super.cause});
}
