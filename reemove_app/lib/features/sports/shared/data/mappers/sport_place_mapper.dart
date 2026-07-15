import '../../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/sport_place.dart';
import '../dto/sport_place_dto.dart';

extension SportPlaceDtoMapper on SportPlaceDto {
  SportPlace toDomain() => SportPlace(
    id: id,
    name: name,
    description: description,
    type: SportPlaceType.values.byName(type),
    sportIds: sportIds,
    location: location.toDomain(),
    addressLine: addressLine,
    city: city,
    countryCode: countryCode,
    media: media.map((item) => item.toDomain()).toList(growable: false),
    pricingText: pricingText,
    rating: rating,
    reviewCount: reviewCount,
    isVerified: isVerified,
    visibility: VisibilityStorageValue.fromStorage(visibility),
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    audit: audit.toDomain(),
  );
}
