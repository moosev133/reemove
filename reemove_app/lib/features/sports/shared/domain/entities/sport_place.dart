import '../../../../../core/domain/entities/entity_audit.dart';
import '../../../../../core/domain/value_objects/content_policy.dart';
import '../../../../../core/domain/value_objects/geo_location.dart';
import '../../../../../core/domain/value_objects/media_asset.dart';

enum SportPlaceType {
  gym,
  court,
  pitch,
  track,
  trail,
  pool,
  studio,
  arena,
  other,
}

class SportPlace {
  const SportPlace({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.sportIds,
    required this.location,
    required this.addressLine,
    required this.city,
    required this.countryCode,
    required this.media,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.visibility,
    required this.moderationState,
    required this.audit,
    this.pricingText,
  });

  final String id;
  final String name;
  final String description;
  final SportPlaceType type;
  final List<String> sportIds;
  final GeoLocation location;
  final String addressLine;
  final String city;
  final String countryCode;
  final List<MediaAsset> media;
  final String? pricingText;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final Visibility visibility;
  final ModerationState moderationState;
  final EntityAudit audit;
}
