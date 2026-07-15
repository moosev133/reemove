import '../../../../core/domain/value_objects/geo_location.dart';

enum NearbyEntityType { place, person, event, route }

class NearbyEntity {
  const NearbyEntity({
    required this.id,
    required this.sourceId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.distanceKm,
    required this.distanceLabel,
    required this.sportIds,
    required this.isVerified,
    required this.isApproximate,
    this.imageUrl,
    this.username,
    this.placeType,
    this.eventType,
    this.routeType,
    this.startsAt,
    this.endsAt,
    this.rating,
    this.capacity,
    this.attendeeCount,
    this.distanceMeters,
    this.elevationGainMeters,
    this.difficulty,
    this.routePath = const <GeoLocation>[],
  });

  final String id;
  final String sourceId;
  final NearbyEntityType type;
  final String title;
  final String subtitle;
  final GeoLocation location;
  final double distanceKm;
  final String distanceLabel;
  final List<String> sportIds;
  final bool isVerified;
  final bool isApproximate;
  final String? imageUrl;
  final String? username;
  final String? placeType;
  final String? eventType;
  final String? routeType;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final double? rating;
  final int? capacity;
  final int? attendeeCount;
  final int? distanceMeters;
  final int? elevationGainMeters;
  final String? difficulty;
  final List<GeoLocation> routePath;

  String get primarySportId => sportIds.isEmpty ? 'running' : sportIds.first;

  String get semanticLabel => switch (type) {
    NearbyEntityType.place => 'Place',
    NearbyEntityType.person => 'Athlete',
    NearbyEntityType.event => 'Event',
    NearbyEntityType.route => 'Route',
  };
}
