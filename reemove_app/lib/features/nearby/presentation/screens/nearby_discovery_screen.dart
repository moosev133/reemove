import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/nearby_providers.dart';
import '../../domain/entities/nearby_entity.dart';
import '../../domain/entities/nearby_search.dart';
import '../../domain/services/maps_availability.dart';
import '../widgets/nearby_filter_bar.dart';
import '../widgets/nearby_map_view.dart';
import '../widgets/nearby_result_card.dart';

class NearbyDiscoveryScreen extends ConsumerStatefulWidget {
  const NearbyDiscoveryScreen({this.sportId, super.key});

  final String? sportId;

  @override
  ConsumerState<NearbyDiscoveryScreen> createState() =>
      _NearbyDiscoveryScreenState();
}

class _NearbyDiscoveryScreenState extends ConsumerState<NearbyDiscoveryScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(nearbyDiscoveryControllerProvider.notifier)
            .initialize(sportId: widget.sportId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NearbyDiscoveryState state = ref.watch(
      nearbyDiscoveryControllerProvider,
    );
    final NearbyDiscoveryController controller = ref.read(
      nearbyDiscoveryControllerProvider.notifier,
    );
    final bool wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sportId == null
              ? 'Nearby'
              : 'Nearby ${_sportLabel(widget.sportId!)}',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Use my current location',
            onPressed: state.isLoading
                ? null
                : () {
                    unawaited(controller.useCurrentLocation());
                  },
            icon: const Icon(Icons.my_location_rounded),
          ),
          IconButton(
            tooltip: 'Refresh nearby results',
            onPressed: state.isLoading
                ? null
                : () {
                    unawaited(controller.refresh());
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            children: <Widget>[
              NearbyFilterBar(
                radiusKm: state.radiusKm,
                types: state.types,
                sportIds: state.sportIds,
                onRadiusChanged: (double value) {
                  unawaited(controller.setRadius(value));
                },
                onTypeToggled: (NearbyEntityType type) {
                  unawaited(controller.toggleType(type));
                },
                onSportToggled: (String sportId) {
                  unawaited(controller.toggleSport(sportId));
                },
              ),
              if (state.isLoading) const LinearProgressIndicator(),
              if (state.errorMessage case final String message)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ErrorBanner(
                    message: message,
                    onRetry: state.center == null
                        ? () {
                            unawaited(controller.useCurrentLocation());
                          }
                        : () {
                            unawaited(controller.refresh());
                          },
                    onSettings: () {
                      unawaited(controller.openApplicationSettings());
                    },
                  ),
                ),
              if (!MapsAvailability.isSdkSupported)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _MapsUnavailableBanner(),
                ),
              Expanded(
                child: state.center == null
                    ? _LocationRequired(
                        onEnable: () {
                          unawaited(controller.useCurrentLocation());
                        },
                        onLocationSettings: () {
                          unawaited(controller.openLocationSettings());
                        },
                      )
                    : wide
                    ? Row(
                        children: <Widget>[
                          if (MapsAvailability.isSdkSupported) ...<Widget>[
                            Expanded(
                              flex: 7,
                              child: NearbyMapView(
                                center: state.center!,
                                radiusKm: state.radiusKm,
                                items: state.items,
                                selectedId: state.selectedId,
                                locationPermissionGranted:
                                    state.locationPermissionGranted,
                                onSelected: controller.select,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                          ],
                          Expanded(
                            flex: MapsAvailability.isSdkSupported ? 4 : 1,
                            child: _ResultsList(
                              state: state,
                              onSelect: controller.select,
                              onOpen: (NearbyEntity item) =>
                                  _openEntity(context, item),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          if (MapsAvailability.isSdkSupported) ...<Widget>[
                            SegmentedButton<NearbyViewMode>(
                              segments: const <ButtonSegment<NearbyViewMode>>[
                                ButtonSegment<NearbyViewMode>(
                                  value: NearbyViewMode.map,
                                  label: Text('Map'),
                                  icon: Icon(Icons.map_outlined),
                                ),
                                ButtonSegment<NearbyViewMode>(
                                  value: NearbyViewMode.list,
                                  label: Text('List'),
                                  icon: Icon(Icons.view_list_outlined),
                                ),
                              ],
                              selected: <NearbyViewMode>{state.viewMode},
                              onSelectionChanged:
                                  (Set<NearbyViewMode> selection) {
                                    controller.setViewMode(selection.first);
                                  },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          Expanded(
                            child:
                                state.viewMode == NearbyViewMode.map &&
                                    MapsAvailability.isSdkSupported
                                ? NearbyMapView(
                                    center: state.center!,
                                    radiusKm: state.radiusKm,
                                    items: state.items,
                                    selectedId: state.selectedId,
                                    locationPermissionGranted:
                                        state.locationPermissionGranted,
                                    onSelected: controller.select,
                                  )
                                : _ResultsList(
                                    state: state,
                                    onSelect: controller.select,
                                    onOpen: (NearbyEntity item) =>
                                        _openEntity(context, item),
                                  ),
                          ),
                          if (state.viewMode == NearbyViewMode.map &&
                              MapsAvailability.isSdkSupported &&
                              state.selectedEntity != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: NearbyResultCard(
                                entity: state.selectedEntity!,
                                isSelected: true,
                                onTap: () =>
                                    controller.select(state.selectedEntity!.id),
                                onOpen: () =>
                                    _openEntity(context, state.selectedEntity!),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _openEntity(BuildContext context, NearbyEntity item) {
    switch (item.type) {
      case NearbyEntityType.place:
        unawaited(
          context.push(
            AppRoutes.sportPlace(item.primarySportId, item.sourceId),
          ),
        );
        return;
      case NearbyEntityType.person:
        final String? username = item.username;
        if (username != null && username.isNotEmpty) {
          unawaited(context.push(AppRoutes.publicProfile(username)));
        }
        return;
      case NearbyEntityType.event:
        unawaited(
          context.push(
            AppRoutes.sportEvent(item.primarySportId, item.sourceId),
          ),
        );
        return;
      case NearbyEntityType.route:
        unawaited(context.push(AppRoutes.sportsRoute(item.sourceId)));
        return;
    }
  }

  static String _sportLabel(String sportId) => switch (sportId) {
    'football' => 'football',
    'gym' => 'gyms',
    'running' => 'running',
    _ => sportId,
  };
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.state,
    required this.onSelect,
    required this.onOpen,
  });

  final NearbyDiscoveryState state;
  final ValueChanged<String> onSelect;
  final ValueChanged<NearbyEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    if (!state.isLoading && state.items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.location_off_outlined,
        title: 'Nothing found in this radius',
        message: 'Increase the distance or select more categories and sports.',
      );
    }
    return ListView.separated(
      restorationId: 'nearby_results',
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final NearbyEntity item = state.items[index];
        return NearbyResultCard(
          entity: item,
          isSelected: item.id == state.selectedId,
          onTap: () => onSelect(item.id),
          onOpen: () => onOpen(item),
        );
      },
    );
  }
}

class _LocationRequired extends StatelessWidget {
  const _LocationRequired({
    required this.onEnable,
    required this.onLocationSettings,
  });

  final VoidCallback onEnable;
  final VoidCallback onLocationSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: PremiumSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.explore_rounded,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Discover what is moving around you',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'ReeMove uses your location only when you open Nearby. People appear at approximate positions, never exact coordinates.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onEnable,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Use my location'),
              ),
              TextButton(
                onPressed: onLocationSettings,
                child: const Text('Open Location Services'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapsUnavailableBanner extends StatelessWidget {
  const _MapsUnavailableBanner();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(Icons.map_outlined, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text(MapsAvailability.unsupportedMessage)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onSettings,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            IconButton(
              tooltip: 'Open app settings',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
