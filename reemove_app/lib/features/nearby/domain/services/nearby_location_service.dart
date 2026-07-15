import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/result/result.dart';

enum NearbyLocationPermission {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class NearbyLocationCapture {
  const NearbyLocationCapture({required this.permission, this.location});

  final NearbyLocationPermission permission;
  final GeoLocation? location;
}

abstract interface class NearbyLocationService {
  Future<Result<NearbyLocationCapture>> requestCurrentLocation();
  Future<bool> openApplicationSettings();
  Future<bool> openLocationSettings();
}
