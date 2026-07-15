import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';

abstract final class ProfileFailureMapper {
  static Failure fromFunctions(FirebaseFunctionsException error) {
    final String message = switch (error.code) {
      'already-exists' => error.message ?? 'This request already exists.',
      'invalid-argument' => error.message ?? 'Check the profile information.',
      'failed-precondition' => error.message ?? 'This action is unavailable.',
      'not-found' => error.message ?? 'This profile is unavailable.',
      'unauthenticated' => 'Sign in again to continue.',
      'permission-denied' => error.message ?? 'You cannot perform this action.',
      'resource-exhausted' => 'Too many attempts. Try again shortly.',
      _ =>
        error.message ?? 'The profile service could not complete the request.',
    };
    return Failure(
      message: message,
      code: error.code,
      debugMessage: error.details?.toString(),
      cause: error,
    );
  }

  static Failure fromFirestore(FirebaseException error) =>
      FirestoreFailureMapper.fromFirebaseException(error);

  static Failure unexpected(Object error) => Failure(
    message: 'ReeMove could not update this profile. Try again.',
    code: 'profile/unexpected',
    debugMessage: error.toString(),
    cause: error,
  );
}
