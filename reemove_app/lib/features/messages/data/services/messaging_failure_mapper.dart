import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';

abstract final class MessagingFailureMapper {
  static Failure fromFunctions(FirebaseFunctionsException error) => Failure(
    message: switch (error.code) {
      'already-exists' => error.message ?? 'This conversation already exists.',
      'invalid-argument' => error.message ?? 'Check the message and try again.',
      'failed-precondition' =>
        error.message ?? 'This messaging action is unavailable.',
      'not-found' => error.message ?? 'This conversation is unavailable.',
      'unauthenticated' => 'Sign in again to continue.',
      'permission-denied' =>
        error.message ?? 'You cannot perform this messaging action.',
      'resource-exhausted' => 'Too many messages. Try again shortly.',
      _ => error.message ?? 'Messaging could not complete the request.',
    },
    code: error.code,
    debugMessage: error.details?.toString(),
    cause: error,
  );

  static Failure fromFirestore(FirebaseException error) =>
      FirestoreFailureMapper.fromFirebaseException(error);

  static Failure fromStorage(FirebaseException error) => Failure(
    message: 'The attachment could not be uploaded.',
    code: 'storage/${error.code}',
    debugMessage: error.message,
    cause: error,
  );

  static Failure fromDatabase(FirebaseException error) => Failure(
    message: 'Live messaging status is temporarily unavailable.',
    code: 'database/${error.code}',
    debugMessage: error.message,
    cause: error,
  );

  static Failure unexpected(Object error) => Failure(
    message: 'ReeMove messaging encountered an unexpected problem.',
    code: 'messages/unexpected',
    debugMessage: error.toString(),
    cause: error,
  );
}
