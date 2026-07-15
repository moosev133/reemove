import '../../../../core/domain/value_objects/geo_location.dart';
import '../services/maps_availability.dart';
import 'nearby_entity.dart';

class NearbySearchRequest {
  const NearbySearchRequest({
    required this.center,
    required this.radiusKm,
    required this.types,
    required this.sportIds,
    this.limit = 60,
  });

  final GeoLocation center;
  final double radiusKm;
  final Set<NearbyEntityType> types;
  final Set<String> sportIds;
  final int limit;
}

class NearbySearchResult {
  const NearbySearchResult({
    required this.items,
    required this.center,
    required this.radiusKm,
    required this.generatedAt,
  });

  final List<NearbyEntity> items;
  final GeoLocation center;
  final double radiusKm;
  final DateTime generatedAt;
}

enum NearbyViewMode { map, list }

class NearbyDiscoveryState {
  const NearbyDiscoveryState({
    required this.radiusKm,
    required this.types,
    required this.sportIds,
    required this.items,
    required this.viewMode,
    required this.isLoading,
    required this.locationPermissionGranted,
    this.center,
    this.selectedId,
    this.errorMessage,
    this.lastUpdatedAt,
  });

  factory NearbyDiscoveryState.initial() => NearbyDiscoveryState(
    radiusKm: 25,
    types: const <NearbyEntityType>{
      NearbyEntityType.place,
      NearbyEntityType.person,
      NearbyEntityType.event,
      NearbyEntityType.route,
    },
    sportIds: const <String>{},
    items: const <NearbyEntity>[],
    viewMode: MapsAvailability.isSdkSupported
        ? NearbyViewMode.map
        : NearbyViewMode.list,
    isLoading: false,
    locationPermissionGranted: false,
  );

  final GeoLocation? center;
  final double radiusKm;
  final Set<NearbyEntityType> types;
  final Set<String> sportIds;
  final List<NearbyEntity> items;
  final NearbyViewMode viewMode;
  final bool isLoading;
  final bool locationPermissionGranted;
  final String? selectedId;
  final String? errorMessage;
  final DateTime? lastUpdatedAt;

  NearbyEntity? get selectedEntity {
    for (final NearbyEntity item in items) {
      if (item.id == selectedId) {
        return item;
      }
    }
    return null;
  }

  NearbyDiscoveryState copyWith({
    GeoLocation? center,
    bool clearCenter = false,
    double? radiusKm,
    Set<NearbyEntityType>? types,
    Set<String>? sportIds,
    List<NearbyEntity>? items,
    NearbyViewMode? viewMode,
    bool? isLoading,
    bool? locationPermissionGranted,
    String? selectedId,
    bool clearSelection = false,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastUpdatedAt,
  }) {
    return NearbyDiscoveryState(
      center: clearCenter ? null : center ?? this.center,
      radiusKm: radiusKm ?? this.radiusKm,
      types: types ?? this.types,
      sportIds: sportIds ?? this.sportIds,
      items: items ?? this.items,
      viewMode: viewMode ?? this.viewMode,
      isLoading: isLoading ?? this.isLoading,
      locationPermissionGranted:
          locationPermissionGranted ?? this.locationPermissionGranted,
      selectedId: clearSelection ? null : selectedId ?? this.selectedId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
