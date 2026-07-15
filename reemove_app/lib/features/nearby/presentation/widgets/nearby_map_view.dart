import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../domain/entities/nearby_entity.dart';
import '../../domain/services/maps_availability.dart';

class NearbyMapView extends StatefulWidget {
  const NearbyMapView({
    required this.center,
    required this.radiusKm,
    required this.items,
    required this.locationPermissionGranted,
    required this.onSelected,
    this.selectedId,
    super.key,
  });

  final GeoLocation center;
  final double radiusKm;
  final List<NearbyEntity> items;
  final bool locationPermissionGranted;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<NearbyMapView> createState() => _NearbyMapViewState();
}

class _NearbyMapViewState extends State<NearbyMapView> {
  final ClusterManager _clusterManager = ClusterManager(
    clusterManagerId: const ClusterManagerId('reemove-nearby'),
  );
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant NearbyMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final GoogleMapController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId) {
      final NearbyEntity? selected = _selected;
      if (selected != null) {
        unawaited(
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(selected.location.latitude, selected.location.longitude),
              15,
            ),
          ),
        );
      }
    } else if (oldWidget.center.latitude != widget.center.latitude ||
        oldWidget.center.longitude != widget.center.longitude) {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(widget.center.latitude, widget.center.longitude),
            13,
          ),
        ),
      );
    }
  }

  NearbyEntity? get _selected {
    for (final NearbyEntity item in widget.items) {
      if (item.id == widget.selectedId) {
        return item;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MapsAvailability.isSdkSupported) {
      return AppEmptyState(
        icon: Icons.map_outlined,
        title: 'Map unavailable',
        message: MapsAvailability.unsupportedMessage,
      );
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final NearbyEntity? selected = _selected;
    final Set<Marker> markers = widget.items.map((NearbyEntity item) {
      final bool isSelected = item.id == widget.selectedId;
      return Marker(
        markerId: MarkerId(item.id),
        clusterManagerId: _clusterManager.clusterManagerId,
        position: LatLng(item.location.latitude, item.location.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : _hue(item.type),
        ),
        zIndexInt: isSelected ? 10 : 1,
        infoWindow: InfoWindow(
          title: item.title,
          snippet: '${item.semanticLabel} • ${item.distanceLabel}',
          onTap: () => widget.onSelected(item.id),
        ),
        onTap: () => widget.onSelected(item.id),
      );
    }).toSet();
    final Set<Polyline> polylines = <Polyline>{
      if (selected != null && selected.routePath.length > 1)
        Polyline(
          polylineId: PolylineId('route-${selected.sourceId}'),
          points: selected.routePath
              .map(
                (GeoLocation point) => LatLng(point.latitude, point.longitude),
              )
              .toList(growable: false),
          width: 6,
          color: scheme.primary,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.center.latitude, widget.center.longitude),
          zoom: 13,
        ),
        onMapCreated: (GoogleMapController controller) {
          _controller = controller;
        },
        clusterManagers: <ClusterManager>{_clusterManager},
        markers: markers,
        polylines: polylines,
        circles: <Circle>{
          Circle(
            circleId: const CircleId('search-radius'),
            center: LatLng(widget.center.latitude, widget.center.longitude),
            radius: widget.radiusKm * 1000,
            fillColor: scheme.primary.withValues(alpha: 0.06),
            strokeColor: scheme.primary.withValues(alpha: 0.45),
            strokeWidth: 2,
          ),
        },
        myLocationEnabled: widget.locationPermissionGranted,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: true,
        buildingsEnabled: true,
        indoorViewEnabled: true,
        onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
    );
  }

  static double _hue(NearbyEntityType type) => switch (type) {
    NearbyEntityType.place => BitmapDescriptor.hueViolet,
    NearbyEntityType.person => BitmapDescriptor.hueCyan,
    NearbyEntityType.event => BitmapDescriptor.hueOrange,
    NearbyEntityType.route => BitmapDescriptor.hueGreen,
  };
}
