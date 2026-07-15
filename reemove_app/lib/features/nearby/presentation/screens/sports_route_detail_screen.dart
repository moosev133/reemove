import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/nearby_providers.dart';
import '../../domain/entities/sports_route.dart';
import '../../domain/services/maps_availability.dart';

class SportsRouteDetailScreen extends ConsumerWidget {
  const SportsRouteDetailScreen({required this.routeId, super.key});

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SportsRoute?> value = ref.watch(
      sportsRouteProvider(routeId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Route')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Route unavailable',
          message: error.toString(),
        ),
        data: (SportsRoute? route) {
          if (route == null) {
            return const AppEmptyState(
              icon: Icons.route_outlined,
              title: 'Route not found',
              message: 'This route may have been removed or made private.',
            );
          }
          final ColorScheme scheme = Theme.of(context).colorScheme;
          return AdaptivePageBody(
            restorationId: 'sports_route_$routeId',
            slivers: <Widget>[
              AppPageHeader(
                eyebrow: route.isVerified
                    ? 'Verified route'
                    : 'Community route',
                title: route.name,
                subtitle: route.description,
                trailing: const Icon(Icons.route_rounded, size: 44),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (route.coverUrl case final String coverUrl)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: AspectRatio(
                    aspectRatio: 16 / 8,
                    child: CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (route.coverUrl != null) const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppStatusChip(
                    label: '${route.distanceKm.toStringAsFixed(1)} km',
                    icon: Icons.straighten_rounded,
                    color: scheme.primary,
                  ),
                  AppStatusChip(
                    label: '${route.elevationGainMeters} m climb',
                    icon: Icons.terrain_rounded,
                    color: scheme.secondary,
                  ),
                  AppStatusChip(
                    label: '${route.estimatedDurationMinutes} min',
                    icon: Icons.schedule_rounded,
                    color: scheme.tertiary,
                  ),
                  AppStatusChip(
                    label: _label(route.difficulty.name),
                    icon: Icons.speed_rounded,
                    color: scheme.primary,
                  ),
                  AppStatusChip(
                    label: _label(route.type.name),
                    icon: Icons.alt_route_rounded,
                    color: scheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 420,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: _RouteMap(route: route),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Route details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(
                      icon: Icons.place_outlined,
                      label: <String>[
                        route.locality,
                        route.city,
                        route.countryCode,
                      ].where((String item) => item.isNotEmpty).join(' • '),
                    ),
                    _DetailRow(
                      icon: Icons.layers_outlined,
                      label: route.surfaceTypes.isEmpty
                          ? 'Surface not specified'
                          : route.surfaceTypes.map(_label).join(' • '),
                    ),
                    _DetailRow(
                      icon: Icons.sports_outlined,
                      label: route.sportIds.map(_label).join(' • '),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Check weather, lighting, opening times, and local safety conditions before starting. Route data may change.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _label(String value) {
    final String spaced = value.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (Match match) => '${match.group(1)} ${match.group(2)}',
    );
    return spaced.isEmpty
        ? spaced
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.route});

  final SportsRoute route;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MapsAvailability.isSdkSupported) {
      return const AppEmptyState(
        icon: Icons.map_outlined,
        title: 'Map unavailable',
        message: MapsAvailability.unsupportedMessage,
      );
    }
    final SportsRoute route = widget.route;
    final List<LatLng> points = route.path
        .map((GeoLocation point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final Color primary = Theme.of(context).colorScheme.primary;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          route.startLocation.latitude,
          route.startLocation.longitude,
        ),
        zoom: 14,
      ),
      onMapCreated: (GoogleMapController controller) async {
        _controller = controller;
        if (points.length > 1) {
          await controller.animateCamera(
            CameraUpdate.newLatLngBounds(_bounds(points), 48),
          );
        }
      },
      markers: <Marker>{
        Marker(
          markerId: const MarkerId('route-start'),
          position: LatLng(
            route.startLocation.latitude,
            route.startLocation.longitude,
          ),
          infoWindow: InfoWindow(title: route.name, snippet: 'Route start'),
        ),
      },
      polylines: <Polyline>{
        if (points.length > 1)
          Polyline(
            polylineId: PolylineId(route.id),
            points: points,
            color: primary,
            width: 7,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
      },
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
    );
  }

  static LatLngBounds _bounds(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;
    for (final LatLng point in points.skip(1)) {
      south = point.latitude < south ? point.latitude : south;
      north = point.latitude > north ? point.latitude : north;
      west = point.longitude < west ? point.longitude : west;
      east = point.longitude > east ? point.longitude : east;
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
