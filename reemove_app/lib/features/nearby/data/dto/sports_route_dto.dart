import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../core/database/firestore_parser.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/geospatial/geohash_encoder.dart';
import '../../domain/entities/sports_route.dart';

class SportsRouteDto {
  const SportsRouteDto({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.sportIds,
    required this.routeType,
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

  factory SportsRouteDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Route ${snapshot.id} has no data.');
    }
    final GeoPoint start = FirestoreParser.geoPoint(data, 'startLocation');
    final List<GeoLocation> points = _path(data['path']);
    return SportsRouteDto(
      id: snapshot.id,
      ownerId: FirestoreParser.string(data, 'ownerId', fallback: 'system'),
      name: FirestoreParser.string(data, 'name'),
      description: FirestoreParser.string(data, 'description', fallback: ''),
      sportIds: FirestoreParser.stringList(data, 'sportIds'),
      routeType: FirestoreParser.string(data, 'routeType', fallback: 'loop'),
      difficulty: FirestoreParser.string(
        data,
        'difficulty',
        fallback: 'moderate',
      ),
      startLocation: GeoLocation(
        latitude: start.latitude,
        longitude: start.longitude,
        geohash: FirestoreParser.string(
          data,
          'geohash',
          fallback: GeohashEncoder.encode(start.latitude, start.longitude),
        ),
        locality: FirestoreParser.nullableString(data, 'locality'),
        administrativeArea: FirestoreParser.nullableString(
          data,
          'administrativeArea',
        ),
        countryCode: FirestoreParser.nullableString(data, 'countryCode'),
      ),
      path: points,
      distanceMeters: FirestoreParser.integer(
        data,
        'distanceMeters',
        fallback: 0,
      ),
      elevationGainMeters: FirestoreParser.integer(
        data,
        'elevationGainMeters',
        fallback: 0,
      ),
      estimatedDurationMinutes: FirestoreParser.integer(
        data,
        'estimatedDurationMinutes',
        fallback: 0,
      ),
      surfaceTypes: FirestoreParser.stringList(data, 'surfaceTypes'),
      locality: FirestoreParser.string(data, 'locality', fallback: ''),
      city: FirestoreParser.string(data, 'city', fallback: ''),
      countryCode: FirestoreParser.string(data, 'countryCode', fallback: ''),
      coverUrl: FirestoreParser.nullableString(data, 'coverUrl'),
      isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
      visibility: FirestoreParser.string(
        data,
        'visibility',
        fallback: 'public',
      ),
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final List<String> sportIds;
  final String routeType;
  final String difficulty;
  final GeoLocation startLocation;
  final List<GeoLocation> path;
  final int distanceMeters;
  final int elevationGainMeters;
  final int estimatedDurationMinutes;
  final List<String> surfaceTypes;
  final String locality;
  final String city;
  final String countryCode;
  final String? coverUrl;
  final bool isVerified;
  final String visibility;
  final String moderationState;
  final EntityAuditDto audit;

  SportsRoute toDomain() => SportsRoute(
    id: id,
    ownerId: ownerId,
    name: name,
    description: description,
    sportIds: sportIds,
    type: SportsRouteType.values.firstWhere(
      (SportsRouteType item) => item.name == routeType,
      orElse: () => SportsRouteType.loop,
    ),
    difficulty: SportsRouteDifficulty.values.firstWhere(
      (SportsRouteDifficulty item) => item.name == difficulty,
      orElse: () => SportsRouteDifficulty.moderate,
    ),
    startLocation: startLocation,
    path: path,
    distanceMeters: distanceMeters,
    elevationGainMeters: elevationGainMeters,
    estimatedDurationMinutes: estimatedDurationMinutes,
    surfaceTypes: surfaceTypes,
    locality: locality,
    city: city,
    countryCode: countryCode,
    coverUrl: coverUrl,
    isVerified: isVerified,
    visibility: VisibilityStorageValue.fromStorage(visibility),
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    audit: audit.toDomain(),
  );

  static List<GeoLocation> _path(Object? value) {
    if (value is! List) {
      return const <GeoLocation>[];
    }
    return value
        .map((Object? point) {
          if (point is GeoPoint) {
            return GeoLocation(
              latitude: point.latitude,
              longitude: point.longitude,
              geohash: GeohashEncoder.encode(point.latitude, point.longitude),
            );
          }
          if (point is Map) {
            final Map<String, dynamic> map = point.cast<String, dynamic>();
            final double latitude = (map['latitude'] as num).toDouble();
            final double longitude = (map['longitude'] as num).toDouble();
            return GeoLocation(
              latitude: latitude,
              longitude: longitude,
              geohash: GeohashEncoder.encode(latitude, longitude),
            );
          }
          throw const FormatException('Invalid route path point.');
        })
        .toList(growable: false);
  }
}
