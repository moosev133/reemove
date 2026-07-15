import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/failure.dart';

abstract final class FirestoreFailureMapper {
  static Failure fromFirebaseException(FirebaseException exception) {
    final String message = switch (exception.code) {
      'permission-denied' => 'You do not have permission to access this data.',
      'unavailable' => 'The service is temporarily unavailable.',
      'deadline-exceeded' => 'The request took too long. Please try again.',
      'not-found' => 'The requested data was not found.',
      'already-exists' => 'This item already exists.',
      'resource-exhausted' => 'The service is busy. Please try again shortly.',
      'unauthenticated' => 'Please sign in to continue.',
      _ => 'Something went wrong while loading data.',
    };

    return Failure(
      message: message,
      code: exception.code,
      debugMessage: exception.message.toString(),
      cause: exception,
    );
  }

  static Failure fromFormatException(FormatException exception) => Failure(
    message: 'The server returned unsupported data.',
    code: 'invalid-document',
    debugMessage: exception.message.toString(),
    cause: exception,
  );

  static Failure unexpected(Object error) => Failure(
    message: 'An unexpected database error occurred.',
    code: 'unexpected-database-error',
    debugMessage: error.toString(),
    cause: error,
  );

  static Failure fromUnknown(Object error) {
    if (error is FirebaseException) {
      return fromFirebaseException(error);
    }
    if (error is FormatException) {
      return fromFormatException(error);
    }
    return unexpected(error);
  }
}
