import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';

abstract final class NotificationFailureMapper {
  static Failure fromFunctions(FirebaseFunctionsException error) => Failure(
    message:
        error.message ?? 'The notification request could not be completed.',
    code: error.code,
    debugMessage: error.details?.toString(),
    cause: error,
  );

  static Failure fromFirestore(FirebaseException error) =>
      FirestoreFailureMapper.fromFirebaseException(error);

  static Failure unexpected(Object error) => Failure(
    message: 'Notifications are temporarily unavailable.',
    code: 'notifications/unexpected',
    debugMessage: error.toString(),
    cause: error,
  );
}
