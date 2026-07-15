import 'package:flutter/material.dart' hide Visibility;

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/app_status_chip.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/sport_place.dart';

class SportPlaceCard extends StatelessWidget {
  const SportPlaceCard({required this.place, required this.onTap, super.key});

  final SportPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return PremiumSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Icon(
                    _icon(place.type),
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            place.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (place.isVerified)
                          Icon(
                            Icons.verified_rounded,
                            color: scheme.primary,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      <String>[place.addressLine, place.city]
                          .where((String item) => item.trim().isNotEmpty)
                          .join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (place.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              place.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppStatusChip(
                label: place.reviewCount == 0
                    ? 'New place'
                    : '${place.rating.toStringAsFixed(1)} • ${place.reviewCount} reviews',
                icon: Icons.star_rounded,
                color: scheme.tertiary,
              ),
              if (place.pricingText case final String price)
                AppStatusChip(
                  label: price,
                  icon: Icons.payments_outlined,
                  color: scheme.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _icon(SportPlaceType type) => switch (type) {
    SportPlaceType.gym => Icons.fitness_center_rounded,
    SportPlaceType.pitch => Icons.sports_soccer_rounded,
    SportPlaceType.track || SportPlaceType.trail => Icons.route_rounded,
    SportPlaceType.court => Icons.sports_tennis_rounded,
    SportPlaceType.pool => Icons.pool_rounded,
    SportPlaceType.studio => Icons.self_improvement_rounded,
    SportPlaceType.arena => Icons.stadium_rounded,
    SportPlaceType.other => Icons.place_rounded,
  };
}
