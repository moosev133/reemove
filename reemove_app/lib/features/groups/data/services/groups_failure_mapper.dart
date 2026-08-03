import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/functions_failure_mapper.dart';

abstract final class GroupsFailureMapper {
  static Failure fromFunctions(FirebaseFunctionsException error) =>
      FunctionsFailureMapper.fromException(error);

  static Failure unexpected(Object error) => Failure(
    code: 'groups-unexpected',
    message: 'Something went wrong while loading this group.',
    cause: error,
  );
}
