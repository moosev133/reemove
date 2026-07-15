import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../errors/failure.dart';

/// Shared callable Cloud Functions failure mapping for non-auth features.
abstract final class FunctionsFailureMapper {
  static Failure fromException(FirebaseFunctionsException exception) {
    final String message = switch (exception.code) {
      'already-exists' => exception.message ?? 'This resource already exists.',
      'invalid-argument' =>
        exception.message ?? 'Check the information entered.',
      'failed-precondition' =>
        exception.message ?? 'This action cannot be completed yet.',
      'unauthenticated' => 'Sign in again to continue.',
      'permission-denied' => 'You do not have permission to do that.',
      'resource-exhausted' => 'Too many attempts. Try again shortly.',
      'unavailable' => 'The service is temporarily unavailable.',
      'not-found' =>
        exception.message ?? 'The requested resource was not found.',
      _ => exception.message ?? 'The service could not complete the request.',
    };

    return Failure(
      message: message,
      code: exception.code,
      debugMessage: exception.details?.toString(),
      cause: exception,
    );
  }
}
