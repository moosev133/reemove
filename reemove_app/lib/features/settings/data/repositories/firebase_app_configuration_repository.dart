import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/app_configuration.dart';
import '../../domain/entities/feature_flag.dart';
import '../../domain/repositories/app_configuration_repository.dart';
import '../dto/app_configuration_dto.dart';
import '../dto/feature_flag_dto.dart';
import '../mappers/app_configuration_mapper.dart';
import '../mappers/feature_flag_mapper.dart';

class FirebaseAppConfigurationRepository implements AppConfigurationRepository {
  const FirebaseAppConfigurationRepository({
    required CollectionReference<AppConfigurationDto> appConfig,
    required CollectionReference<FeatureFlagDto> featureFlags,
  }) : _appConfig = appConfig,
       _featureFlags = featureFlags;

  final CollectionReference<AppConfigurationDto> _appConfig;
  final CollectionReference<FeatureFlagDto> _featureFlags;

  @override
  Stream<Result<AppConfiguration?>> watchConfiguration({
    String documentId = 'mobile',
  }) async* {
    try {
      await for (final DocumentSnapshot<AppConfigurationDto> snapshot
          in _appConfig.doc(documentId).snapshots()) {
        yield Success<AppConfiguration?>(snapshot.data()?.toDomain());
      }
    } catch (error) {
      yield FailureResult<AppConfiguration?>(_mapError(error));
    }
  }

  @override
  Stream<Result<List<FeatureFlag>>> watchFeatureFlags() async* {
    try {
      await for (final QuerySnapshot<FeatureFlagDto> snapshot
          in _featureFlags.snapshots()) {
        yield Success<List<FeatureFlag>>(
          snapshot.docs
              .map((doc) => doc.data().toDomain())
              .toList(growable: false),
        );
      }
    } catch (error) {
      yield FailureResult<List<FeatureFlag>>(_mapError(error));
    }
  }

  static Failure _mapError(Object error) {
    if (error is FirebaseException) {
      return FirestoreFailureMapper.fromFirebaseException(error);
    }
    if (error is FormatException) {
      return FirestoreFailureMapper.fromFormatException(error);
    }
    return FirestoreFailureMapper.unexpected(error);
  }
}
