import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../../core/database/firestore_failure_mapper.dart';
import '../../../../../core/errors/failure.dart';
import '../../../../../core/firebase/functions_failure_mapper.dart';

abstract final class SportsFailureMapper {
  static Failure fromFirestore(FirebaseException error) =>
      FirestoreFailureMapper.fromFirebaseException(error);

  static Failure fromFunctions(FirebaseFunctionsException error) =>
      FunctionsFailureMapper.fromException(error);

  static Failure unexpected(Object error) => Failure(
    code: 'sports-unexpected',
    message: 'Something went wrong while loading this sports hub.',
    cause: error,
  );
}
