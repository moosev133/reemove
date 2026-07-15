import '../../../../core/domain/entities/entity_audit.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/geo_location.dart';

enum SportsRouteType { loop, outAndBack, pointToPoint, track }

enum SportsRouteDifficulty { easy, moderate, hard, expert }

class SportsRoute {
  const SportsRoute({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.sportIds,
    required this.type,
    required this.difficulty,
    required this.startLocation,
    required this.path,
    required this.distanceMeters,
    required this.elevationGainMeters,
    required this.estimatedDurationMinutes,
    required this.surfaceTypes,
    required this.locality,
    required this.city,
    required this.countryCode,
    required this.isVerified,
    required this.visibility,
    required this.moderationState,
    required this.audit,
    this.coverUrl,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final List<String> sportIds;
  final SportsRouteType type;
  final SportsRouteDifficulty difficulty;
  final GeoLocation startLocation;
  final List<GeoLocation> path;
  final int distanceMeters;
  final int elevationGainMeters;
  final int estimatedDurationMinutes;
  final List<String> surfaceTypes;
  final String locality;
  final String city;
  final String countryCode;
  final bool isVerified;
  final Visibility visibility;
  final ModerationState moderationState;
  final EntityAudit audit;
  final String? coverUrl;

  double get distanceKm => distanceMeters / 1000;
}
