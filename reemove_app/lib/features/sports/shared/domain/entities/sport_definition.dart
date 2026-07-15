import '../../../../../core/domain/entities/entity_audit.dart';

class SportDefinition {
  const SportDefinition({
    required this.id,
    required this.slug,
    required this.localizedNames,
    required this.iconKey,
    required this.isEnabled,
    required this.sortOrder,
    required this.supportedFeatures,
    required this.audit,
  });

  final String id;
  final String slug;
  final Map<String, String> localizedNames;
  final String iconKey;
  final bool isEnabled;
  final int sortOrder;
  final List<String> supportedFeatures;
  final EntityAudit audit;

  String displayName(String localeCode) =>
      localizedNames[localeCode] ?? localizedNames['en'] ?? slug;
}
