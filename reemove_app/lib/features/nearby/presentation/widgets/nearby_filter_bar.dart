import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/nearby_entity.dart';

class NearbyFilterBar extends StatelessWidget {
  const NearbyFilterBar({
    required this.radiusKm,
    required this.types,
    required this.sportIds,
    required this.onRadiusChanged,
    required this.onTypeToggled,
    required this.onSportToggled,
    super.key,
  });

  final double radiusKm;
  final Set<NearbyEntityType> types;
  final Set<String> sportIds;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<NearbyEntityType> onTypeToggled;
  final ValueChanged<String> onSportToggled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final NearbyEntityType type
                  in NearbyEntityType.values) ...<Widget>[
                FilterChip(
                  selected: types.contains(type),
                  avatar: Icon(_icon(type), size: 18),
                  label: Text(_label(type)),
                  onSelected: (_) => onTypeToggled(type),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              const SizedBox(width: AppSpacing.sm),
              for (final String sport in const <String>[
                'football',
                'gym',
                'running',
              ]) ...<Widget>[
                FilterChip(
                  selected: sportIds.contains(sport),
                  label: Text(_sportLabel(sport)),
                  onSelected: (_) => onSportToggled(sport),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            const Icon(Icons.radar_rounded, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text('${radiusKm.round()} km radius'),
            Expanded(
              child: Slider(
                value: radiusKm,
                min: 1,
                max: 100,
                divisions: 99,
                label: '${radiusKm.round()} km',
                onChanged: onRadiusChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _label(NearbyEntityType type) => switch (type) {
    NearbyEntityType.place => 'Places',
    NearbyEntityType.person => 'People',
    NearbyEntityType.event => 'Events',
    NearbyEntityType.route => 'Routes',
  };

  static IconData _icon(NearbyEntityType type) => switch (type) {
    NearbyEntityType.place => Icons.place_outlined,
    NearbyEntityType.person => Icons.people_outline_rounded,
    NearbyEntityType.event => Icons.event_outlined,
    NearbyEntityType.route => Icons.route_outlined,
  };

  static String _sportLabel(String sport) => switch (sport) {
    'football' => 'Football',
    'gym' => 'Gym',
    'running' => 'Running',
    _ => sport,
  };
}
