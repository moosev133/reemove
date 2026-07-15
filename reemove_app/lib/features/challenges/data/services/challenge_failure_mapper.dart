import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';

abstract final class ChallengeFailureMapper {
  static Failure fromFunctions(FirebaseFunctionsException error) => Failure(
    message: switch (error.code) {
      'invalid-argument' => error.message ?? 'Check the challenge details.',
      'failed-precondition' =>
        error.message ?? 'This challenge action is unavailable.',
      'permission-denied' =>
        error.message ?? 'You cannot perform this challenge action.',
      'resource-exhausted' =>
        error.message ?? 'Too many challenge requests. Try again later.',
      'not-found' => error.message ?? 'This challenge is unavailable.',
      _ => error.message ?? 'ReeMove could not complete this challenge action.',
    },
    code: error.code,
    debugMessage: error.details?.toString(),
    cause: error,
  );

  static Failure fromFirestore(FirebaseException error) =>
      FirestoreFailureMapper.fromFirebaseException(error);

  static Failure fromStorage(FirebaseException error) => Failure(
    message: switch (error.code) {
      'unauthorized' => 'You cannot upload proof for this challenge.',
      'retry-limit-exceeded' => 'The upload timed out. Try again.',
      'quota-exceeded' => 'Uploads are temporarily unavailable.',
      _ => 'ReeMove could not upload this proof.',
    },
    code: error.code,
    debugMessage: error.message,
    cause: error,
  );

  static Failure unexpected(Object error) => Failure(
    message: 'ReeMove could not complete this challenge action.',
    code: 'challenge/unexpected',
    debugMessage: error.toString(),
    cause: error,
  );
}
