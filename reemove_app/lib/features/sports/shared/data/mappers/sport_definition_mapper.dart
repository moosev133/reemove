import '../../domain/entities/sport_definition.dart';
import '../dto/sport_definition_dto.dart';

extension SportDefinitionDtoMapper on SportDefinitionDto {
  SportDefinition toDomain() => SportDefinition(
    id: id,
    slug: slug,
    localizedNames: localizedNames,
    iconKey: iconKey,
    isEnabled: isEnabled,
    sortOrder: sortOrder,
    supportedFeatures: supportedFeatures,
    audit: audit.toDomain(),
  );
}
