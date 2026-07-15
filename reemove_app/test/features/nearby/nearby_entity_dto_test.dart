import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/nearby/data/dto/nearby_entity_dto.dart';
import 'package:reemove/features/nearby/domain/entities/nearby_entity.dart';

void main() {
  test('maps a callable nearby route payload into a domain entity', () {
    final NearbyEntity entity = NearbyEntityDto.fromMap(<String, dynamic>{
      'id': 'route_coastal',
      'sourceId': 'coastal',
      'type': 'route',
      'title': 'Coastal Loop',
      'subtitle': 'Haifa Promenade',
      'location': <String, dynamic>{'latitude': 32.8191, 'longitude': 34.9569},
      'geohash': 'svbcw',
      'distanceKm': 2.4,
      'distanceLabel': '2.4 km away',
      'sportIds': <String>['running'],
      'verified': true,
      'approximate': false,
      'distanceMeters': 5000,
      'elevationGainMeters': 22,
      'difficulty': 'easy',
      'path': <Map<String, dynamic>>[
        <String, dynamic>{'latitude': 32.8191, 'longitude': 34.9569},
        <String, dynamic>{'latitude': 32.8224, 'longitude': 34.9596},
      ],
    }).toDomain();

    expect(entity.type, NearbyEntityType.route);
    expect(entity.primarySportId, 'running');
    expect(entity.routePath, hasLength(2));
    expect(entity.isVerified, isTrue);
    expect(entity.isApproximate, isFalse);
  });

  test('preserves approximate people distance semantics', () {
    final NearbyEntity entity = NearbyEntityDto.fromMap(<String, dynamic>{
      'id': 'person_maya',
      'sourceId': 'maya',
      'type': 'person',
      'title': 'Maya Runner',
      'subtitle': 'running',
      'username': 'maya_runner',
      'location': <String, dynamic>{'latitude': 32.82, 'longitude': 34.96},
      'distanceKm': 3,
      'distanceLabel': 'About 3 km away',
      'sportIds': <String>['running'],
      'verified': true,
      'approximate': true,
    }).toDomain();

    expect(entity.type, NearbyEntityType.person);
    expect(entity.distanceLabel, startsWith('About'));
    expect(entity.isApproximate, isTrue);
  });
}
