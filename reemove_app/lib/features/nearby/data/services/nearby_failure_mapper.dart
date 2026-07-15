import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/errors/failure.dart';

abstract final class NearbyFailureMapper {
  static Failure fromFunctions(FirebaseFunctionsException exception) => Failure(
    message: switch (exception.code) {
      'invalid-argument' =>
        exception.message ?? 'Check the nearby search filters.',
      'failed-precondition' =>
        exception.message ?? 'Nearby discovery is not available yet.',
      'permission-denied' =>
        'Your account cannot access nearby discovery right now.',
      'resource-exhausted' =>
        'Too many nearby searches. Wait a moment and try again.',
      'unauthenticated' => 'Sign in again to use nearby discovery.',
      'unavailable' => 'Nearby discovery is temporarily unavailable.',
      _ => exception.message ?? 'Nearby discovery could not complete.',
    },
    code: exception.code,
    debugMessage: exception.details?.toString(),
    cause: exception,
  );

  static Failure fromFirestore(FirebaseException exception) => Failure(
    message: switch (exception.code) {
      'permission-denied' => 'This route is not available to your account.',
      'not-found' => 'This route no longer exists.',
      'unavailable' => 'Route details are temporarily unavailable.',
      _ => 'Route details could not be loaded.',
    },
    code: exception.code,
    debugMessage: exception.message,
    cause: exception,
  );

  static Failure fromFormat(FormatException exception) => Failure(
    message: 'The nearby service returned unsupported data.',
    code: 'nearby/invalid-data',
    debugMessage: exception.message.toString(),
    cause: exception,
  );

  static Failure unexpected(Object error) => Failure(
    message: 'An unexpected nearby-discovery error occurred.',
    code: 'nearby/unexpected',
    debugMessage: error.toString(),
    cause: error,
  );
}
