import '../../../../core/domain/entities/entity_audit.dart';

class AppConfiguration {
  const AppConfiguration({
    required this.id,
    required this.maintenanceMode,
    required this.minimumSupportedBuild,
    required this.latestBuild,
    required this.defaultDiscoveryRadiusKm,
    required this.supportedCountryCodes,
    required this.termsVersion,
    required this.privacyVersion,
    required this.maxUploadBytes,
    required this.audit,
  });

  final String id;
  final bool maintenanceMode;
  final int minimumSupportedBuild;
  final int latestBuild;
  final double defaultDiscoveryRadiusKm;
  final List<String> supportedCountryCodes;
  final String termsVersion;
  final String privacyVersion;
  final Map<String, int> maxUploadBytes;
  final EntityAudit audit;
}
