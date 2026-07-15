import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';

abstract final class MarketplaceFailureMapper {
  static Failure fromFunctions(FirebaseFunctionsException error) {
    return Failure(
      code: error.code,
      message:
          error.message ?? 'The marketplace request could not be completed.',
      cause: error,
    );
  }

  static Failure fromFirestore(FirebaseException error) =>
      FirestoreFailureMapper.fromFirebaseException(error);

  static Failure fromStorage(FirebaseException error) => Failure(
    code: error.code,
    message: error.message ?? 'The marketplace image could not be uploaded.',
    cause: error,
  );

  static Failure unexpected(Object error) => Failure(
    code: 'marketplace-unexpected',
    message: 'Something went wrong in Marketplace. Try again.',
    cause: error,
  );
}
