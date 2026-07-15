import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/result/result.dart';
import '../entities/onboarding_draft.dart';

class LocationCapture {
  const LocationCapture({required this.permission, this.location});

  final PermissionDecision permission;
  final GeoLocation? location;
}

abstract interface class LocationService {
  Future<Result<LocationCapture>> requestCurrentLocation();
  Future<bool> openApplicationSettings();
  Future<bool> openDeviceLocationSettings();
}
