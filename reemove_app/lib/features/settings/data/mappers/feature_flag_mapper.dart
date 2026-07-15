import '../../domain/entities/feature_flag.dart';
import '../dto/feature_flag_dto.dart';

extension FeatureFlagDtoMapper on FeatureFlagDto {
  FeatureFlag toDomain() => FeatureFlag(
    id: id,
    enabled: enabled,
    rolloutPercentage: rolloutPercentage,
    allowedPlatforms: allowedPlatforms,
    minimumBuild: minimumBuild,
    description: description,
    audit: audit.toDomain(),
  );
}
