import '../../domain/entities/app_configuration.dart';
import '../dto/app_configuration_dto.dart';

extension AppConfigurationDtoMapper on AppConfigurationDto {
  AppConfiguration toDomain() => AppConfiguration(
    id: id,
    maintenanceMode: maintenanceMode,
    minimumSupportedBuild: minimumSupportedBuild,
    latestBuild: latestBuild,
    defaultDiscoveryRadiusKm: defaultDiscoveryRadiusKm,
    supportedCountryCodes: supportedCountryCodes,
    termsVersion: termsVersion,
    privacyVersion: privacyVersion,
    maxUploadBytes: maxUploadBytes,
    audit: audit.toDomain(),
  );
}
