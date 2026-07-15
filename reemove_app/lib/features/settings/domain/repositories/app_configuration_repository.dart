import '../../../../core/result/result.dart';
import '../entities/app_configuration.dart';
import '../entities/feature_flag.dart';

abstract interface class AppConfigurationRepository {
  Stream<Result<AppConfiguration?>> watchConfiguration({
    String documentId = 'mobile',
  });
  Stream<Result<List<FeatureFlag>>> watchFeatureFlags();
}
