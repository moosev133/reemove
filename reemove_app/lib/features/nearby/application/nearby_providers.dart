import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/result/result.dart';
import '../../authentication/application/authentication_providers.dart';
import '../../profile/domain/entities/user_profile.dart';
import '../data/repositories/firebase_nearby_repository.dart';
import '../data/services/platform_nearby_location_service.dart';
import '../domain/entities/nearby_entity.dart';
import '../domain/entities/nearby_search.dart';
import '../domain/entities/sports_route.dart';
import '../domain/repositories/nearby_repository.dart';
import '../domain/services/maps_availability.dart';
import '../domain/services/nearby_location_service.dart';

final Provider<NearbyRepository> nearbyRepositoryProvider =
    Provider<NearbyRepository>((Ref ref) {
      return FirebaseNearbyRepository(
        functions: ref.watch(firebaseFunctionsProvider),
        firestore: ref.watch(firebaseFirestoreProvider),
      );
    });

final Provider<NearbyLocationService> nearbyLocationServiceProvider =
    Provider<NearbyLocationService>((Ref ref) {
      return const PlatformNearbyLocationService();
    });

final sportsRouteProvider = StreamProvider.family<SportsRoute?, String>((
  Ref ref,
  String routeId,
) async* {
  await for (final Result<SportsRoute?> result
      in ref.watch(nearbyRepositoryProvider).watchRoute(routeId)) {
    yield _value(result);
  }
});

final NotifierProvider<NearbyDiscoveryController, NearbyDiscoveryState>
nearbyDiscoveryControllerProvider =
    NotifierProvider<NearbyDiscoveryController, NearbyDiscoveryState>(
      NearbyDiscoveryController.new,
    );

class NearbyDiscoveryController extends Notifier<NearbyDiscoveryState> {
  bool _initialized = false;
  Timer? _radiusDebounce;

  @override
  NearbyDiscoveryState build() {
    ref.onDispose(() => _radiusDebounce?.cancel());
    return NearbyDiscoveryState.initial();
  }

  Future<void> initialize({String? sportId}) async {
    if (_initialized) {
      if (sportId != null &&
          sportId.isNotEmpty &&
          !state.sportIds.contains(sportId)) {
        state = state.copyWith(sportIds: <String>{sportId});
        await refresh();
      }
      return;
    }
    _initialized = true;
    if (sportId != null && sportId.isNotEmpty) {
      state = state.copyWith(sportIds: <String>{sportId});
    }
    final UserProfile? profile = await ref.read(
      currentUserProfileProvider.future,
    );
    if (profile?.location != null) {
      state = state.copyWith(center: profile!.location, clearError: true);
      await refresh();
      return;
    }
    await useCurrentLocation(syncProfile: false);
  }

  Future<void> refresh() async {
    final center = state.center;
    if (center == null || state.types.isEmpty) {
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final Result<NearbySearchResult> result = await ref
        .read(nearbyRepositoryProvider)
        .search(
          NearbySearchRequest(
            center: center,
            radiusKm: state.radiusKm,
            types: state.types,
            sportIds: state.sportIds,
          ),
        );
    result.when<void>(
      success: (NearbySearchResult value) {
        final String? selected = state.selectedId;
        final bool selectionStillExists =
            selected != null && value.items.any((item) => item.id == selected);
        state = state.copyWith(
          center: value.center,
          radiusKm: value.radiusKm,
          items: value.items,
          isLoading: false,
          lastUpdatedAt: value.generatedAt,
          selectedId: selectionStillExists ? selected : null,
          clearSelection: !selectionStillExists,
          clearError: true,
        );
      },
      failure: (Failure failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<void> useCurrentLocation({bool syncProfile = true}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final Result<NearbyLocationCapture> capture = await ref
        .read(nearbyLocationServiceProvider)
        .requestCurrentLocation();
    await capture.when<Future<void>>(
      success: (NearbyLocationCapture value) async {
        final location = value.location;
        if (value.permission != NearbyLocationPermission.granted ||
            location == null) {
          state = state.copyWith(
            isLoading: false,
            locationPermissionGranted: false,
            errorMessage: switch (value.permission) {
              NearbyLocationPermission.denied =>
                'Location permission was declined. You can enable it and try again.',
              NearbyLocationPermission.deniedForever =>
                'Location is blocked in system settings. Open settings to enable it.',
              NearbyLocationPermission.serviceDisabled =>
                'Turn on Location Services to discover activity nearby.',
              NearbyLocationPermission.granted =>
                'Your location could not be determined.',
            },
          );
          return;
        }
        state = state.copyWith(
          center: location,
          locationPermissionGranted: true,
          clearError: true,
        );
        if (syncProfile) {
          final Result<void> update = await ref
              .read(nearbyRepositoryProvider)
              .updateDiscoveryLocation(location);
          update.when<void>(
            success: (_) {},
            failure: (Failure failure) {
              state = state.copyWith(errorMessage: failure.message);
            },
          );
        }
        await refresh();
      },
      failure: (Failure failure) async {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<void> setRadius(double radiusKm) async {
    state = state.copyWith(radiusKm: radiusKm.clamp(1, 100).toDouble());
    _radiusDebounce?.cancel();
    _radiusDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(refresh()),
    );
  }

  Future<void> toggleType(NearbyEntityType type) async {
    final Set<NearbyEntityType> next = Set<NearbyEntityType>.from(state.types);
    if (next.contains(type)) {
      if (next.length == 1) {
        return;
      }
      next.remove(type);
    } else {
      next.add(type);
    }
    state = state.copyWith(types: next, clearSelection: true);
    await refresh();
  }

  Future<void> toggleSport(String sportId) async {
    final Set<String> next = Set<String>.from(state.sportIds);
    if (!next.add(sportId)) {
      next.remove(sportId);
    }
    state = state.copyWith(sportIds: next, clearSelection: true);
    await refresh();
  }

  void select(String? entityId) {
    if (entityId == null) {
      state = state.copyWith(clearSelection: true);
      return;
    }
    state = state.copyWith(selectedId: entityId);
  }

  void setViewMode(NearbyViewMode mode) {
    if (mode == NearbyViewMode.map && !MapsAvailability.isSdkSupported) {
      state = state.copyWith(viewMode: NearbyViewMode.list);
      return;
    }
    state = state.copyWith(viewMode: mode);
  }

  Future<bool> openApplicationSettings() =>
      ref.read(nearbyLocationServiceProvider).openApplicationSettings();

  Future<bool> openLocationSettings() =>
      ref.read(nearbyLocationServiceProvider).openLocationSettings();
}

T _value<T>(Result<T> result) => result.when<T>(
  success: (T value) => value,
  failure: (Failure failure) => throw StateError(failure.message),
);
