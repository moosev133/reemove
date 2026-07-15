import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/result/result.dart';
import '../entities/nearby_search.dart';
import '../entities/sports_route.dart';

abstract interface class NearbyRepository {
  Future<Result<NearbySearchResult>> search(NearbySearchRequest request);
  Future<Result<void>> updateDiscoveryLocation(GeoLocation location);
  Stream<Result<SportsRoute?>> watchRoute(String routeId);
}
