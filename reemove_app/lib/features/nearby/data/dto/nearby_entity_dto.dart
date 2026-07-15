import '../../../../core/database/firestore_parser.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/geospatial/geohash_encoder.dart';
import '../../domain/entities/nearby_entity.dart';

class NearbyEntityDto {
  const NearbyEntityDto({required this.data});

  factory NearbyEntityDto.fromMap(Map<String, dynamic> data) =>
      NearbyEntityDto(data: data);

  final Map<String, dynamic> data;

  NearbyEntity toDomain() {
    final FirestoreMap location = FirestoreParser.map(data, 'location');
    final double latitude = FirestoreParser.number(location, 'latitude');
    final double longitude = FirestoreParser.number(location, 'longitude');
    final String typeName = FirestoreParser.string(data, 'type');
    final List<FirestoreMap> rawPath = FirestoreParser.mapList(data, 'path');
    return NearbyEntity(
      id: FirestoreParser.string(data, 'id'),
      sourceId: FirestoreParser.string(data, 'sourceId'),
      type: NearbyEntityType.values.firstWhere(
        (NearbyEntityType item) => item.name == typeName,
        orElse: () => NearbyEntityType.place,
      ),
      title: FirestoreParser.string(data, 'title'),
      subtitle: FirestoreParser.string(data, 'subtitle', fallback: ''),
      location: GeoLocation(
        latitude: latitude,
        longitude: longitude,
        geohash: FirestoreParser.string(
          data,
          'geohash',
          fallback: GeohashEncoder.encode(latitude, longitude),
        ),
      ),
      distanceKm: FirestoreParser.number(data, 'distanceKm', fallback: 0),
      distanceLabel: FirestoreParser.string(
        data,
        'distanceLabel',
        fallback: 'Nearby',
      ),
      sportIds: FirestoreParser.stringList(data, 'sportIds'),
      isVerified: FirestoreParser.boolean(data, 'verified', fallback: false),
      isApproximate: FirestoreParser.boolean(
        data,
        'approximate',
        fallback: false,
      ),
      imageUrl: FirestoreParser.nullableString(data, 'imageUrl'),
      username: FirestoreParser.nullableString(data, 'username'),
      placeType: FirestoreParser.nullableString(data, 'placeType'),
      eventType: FirestoreParser.nullableString(data, 'eventType'),
      routeType: FirestoreParser.nullableString(data, 'routeType'),
      startsAt: FirestoreParser.nullableDateTime(data, 'startsAt'),
      endsAt: FirestoreParser.nullableDateTime(data, 'endsAt'),
      rating: data['rating'] is num ? (data['rating'] as num).toDouble() : null,
      capacity: FirestoreParser.nullableInteger(data, 'capacity'),
      attendeeCount: FirestoreParser.nullableInteger(data, 'attendeeCount'),
      distanceMeters: FirestoreParser.nullableInteger(data, 'distanceMeters'),
      elevationGainMeters: FirestoreParser.nullableInteger(
        data,
        'elevationGainMeters',
      ),
      difficulty: FirestoreParser.nullableString(data, 'difficulty'),
      routePath: rawPath
          .map((FirestoreMap point) {
            final double pointLatitude = FirestoreParser.number(
              point,
              'latitude',
            );
            final double pointLongitude = FirestoreParser.number(
              point,
              'longitude',
            );
            return GeoLocation(
              latitude: pointLatitude,
              longitude: pointLongitude,
              geohash: GeohashEncoder.encode(pointLatitude, pointLongitude),
            );
          })
          .toList(growable: false),
    );
  }
}
