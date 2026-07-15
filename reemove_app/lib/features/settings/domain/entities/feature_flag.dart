import '../../../../core/domain/entities/entity_audit.dart';

class FeatureFlag {
  const FeatureFlag({
    required this.id,
    required this.enabled,
    required this.rolloutPercentage,
    required this.allowedPlatforms,
    required this.minimumBuild,
    required this.description,
    required this.audit,
  }) : assert(rolloutPercentage >= 0 && rolloutPercentage <= 100);

  final String id;
  final bool enabled;
  final int rolloutPercentage;
  final List<String> allowedPlatforms;
  final int minimumBuild;
  final String description;
  final EntityAudit audit;
}
