import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/database/firestore_parser.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/nearby_entity.dart';
import '../../domain/entities/nearby_search.dart';
import '../../domain/entities/sports_route.dart';
import '../../domain/repositories/nearby_repository.dart';
import '../dto/nearby_entity_dto.dart';
import '../dto/sports_route_dto.dart';
import '../services/nearby_failure_mapper.dart';

class FirebaseNearbyRepository implements NearbyRepository {
  const FirebaseNearbyRepository({
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
  }) : _functions = functions,
       _firestore = firestore;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  @override
  Future<Result<NearbySearchResult>> search(NearbySearchRequest request) async {
    try {
      final HttpsCallableResult<Object?> response = await _functions
          .httpsCallable('searchNearby')
          .call<Object?>(<String, Object?>{
            'latitude': request.center.latitude,
            'longitude': request.center.longitude,
            'radiusKm': request.radiusKm,
            'types': request.types
                .map((NearbyEntityType item) => item.name)
                .toList(growable: false),
            'sportIds': request.sportIds.toList(growable: false),
            'limit': request.limit,
          });
      final FirestoreMap data = _map(response.data);
      final Object? rawItems = data['items'];
      if (rawItems is! List) {
        throw const FormatException('Nearby items are missing.');
      }
      final List<NearbyEntity> items = rawItems
          .map((Object? item) {
            if (item is! Map) {
              throw const FormatException('A nearby item is invalid.');
            }
            return NearbyEntityDto.fromMap(
              item.cast<String, dynamic>(),
            ).toDomain();
          })
          .toList(growable: false);
      final FirestoreMap rawCenter = FirestoreParser.map(data, 'center');
      final double latitude = FirestoreParser.number(rawCenter, 'latitude');
      final double longitude = FirestoreParser.number(rawCenter, 'longitude');
      return Success<NearbySearchResult>(
        NearbySearchResult(
          items: items,
          center: GeoLocation(
            latitude: latitude,
            longitude: longitude,
            geohash: request.center.geohash,
            locality: request.center.locality,
            administrativeArea: request.center.administrativeArea,
            countryCode: request.center.countryCode,
          ),
          radiusKm: FirestoreParser.number(
            data,
            'radiusKm',
            fallback: request.radiusKm,
          ),
          generatedAt: FirestoreParser.dateTime(data, 'generatedAt'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<NearbySearchResult>(
        NearbyFailureMapper.fromFunctions(error),
      );
    } on FormatException catch (error) {
      return FailureResult<NearbySearchResult>(
        NearbyFailureMapper.fromFormat(error),
      );
    } on Object catch (error) {
      return FailureResult<NearbySearchResult>(
        NearbyFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> updateDiscoveryLocation(GeoLocation location) async {
    try {
      await _functions.httpsCallable('updateDiscoveryLocation').call<Object?>(
        <String, Object?>{
          'latitude': location.latitude,
          'longitude': location.longitude,
          if (location.locality != null) 'locality': location.locality,
          if (location.administrativeArea != null)
            'administrativeArea': location.administrativeArea,
          if (location.countryCode != null) 'countryCode': location.countryCode,
        },
      );
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(NearbyFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<void>(NearbyFailureMapper.unexpected(error));
    }
  }

  @override
  Stream<Result<SportsRoute?>> watchRoute(String routeId) async* {
    try {
      final DocumentReference<SportsRouteDto> reference = _firestore
          .collection('sports_routes')
          .withConverter<SportsRouteDto>(
            fromFirestore: SportsRouteDto.fromFirestore,
            toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
          )
          .doc(routeId);
      await for (final DocumentSnapshot<SportsRouteDto> snapshot
          in reference.snapshots()) {
        yield Success<SportsRoute?>(snapshot.data()?.toDomain());
      }
    } on FirebaseException catch (error) {
      yield FailureResult<SportsRoute?>(
        NearbyFailureMapper.fromFirestore(error),
      );
    } on FormatException catch (error) {
      yield FailureResult<SportsRoute?>(NearbyFailureMapper.fromFormat(error));
    } on Object catch (error) {
      yield FailureResult<SportsRoute?>(NearbyFailureMapper.unexpected(error));
    }
  }

  static FirestoreMap _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const FormatException('The nearby response is invalid.');
  }
}
