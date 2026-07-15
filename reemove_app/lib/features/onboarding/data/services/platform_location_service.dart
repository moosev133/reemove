import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/geospatial/geohash_encoder.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../../domain/services/location_service.dart';

class PlatformLocationService implements LocationService {
  const PlatformLocationService();

  @override
  Future<Result<LocationCapture>> requestCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const Success<LocationCapture>(
          LocationCapture(permission: PermissionDecision.unavailable),
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const Success<LocationCapture>(
          LocationCapture(permission: PermissionDecision.denied),
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const Success<LocationCapture>(
          LocationCapture(permission: PermissionDecision.deniedForever),
        );
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      Placemark? placemark;
      try {
        final List<Placemark> places = await Geocoding()
            .placemarkFromCoordinates(position.latitude, position.longitude);
        if (places.isNotEmpty) {
          placemark = places.first;
        }
      } catch (_) {
        // Coordinates remain useful when the platform geocoder is unavailable.
      }

      return Success<LocationCapture>(
        LocationCapture(
          permission: PermissionDecision.granted,
          location: GeoLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            geohash: GeohashEncoder.encode(
              position.latitude,
              position.longitude,
            ),
            locality:
                _clean(placemark?.locality) ??
                _clean(placemark?.subAdministrativeArea),
            administrativeArea: _clean(placemark?.administrativeArea),
            countryCode: _clean(placemark?.isoCountryCode)?.toUpperCase(),
          ),
        ),
      );
    } on TimeoutException catch (error) {
      return FailureResult<LocationCapture>(
        Failure(
          message: 'Location took too long. Move near a window and try again.',
          code: 'location/timeout',
          cause: error,
        ),
      );
    } catch (error) {
      return FailureResult<LocationCapture>(
        Failure(
          message: 'ReeMove could not access your location. Try again.',
          code: 'location/unexpected',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }

  @override
  Future<bool> openApplicationSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openDeviceLocationSettings() =>
      Geolocator.openLocationSettings();

  static String? _clean(String? value) {
    final String? normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
