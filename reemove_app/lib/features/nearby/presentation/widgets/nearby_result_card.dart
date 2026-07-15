import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/nearby_entity.dart';

class NearbyResultCard extends StatelessWidget {
  const NearbyResultCard({
    required this.entity,
    required this.onTap,
    required this.onOpen,
    this.isSelected = false,
    super.key,
  });

  final NearbyEntity entity;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: isSelected ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: PremiumSurface(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Thumbnail(entity: entity),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entity.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entity.isVerified)
                        Icon(
                          Icons.verified_rounded,
                          color: scheme.primary,
                          size: 19,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entity.subtitle.isEmpty
                        ? entity.semanticLabel
                        : entity.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      AppStatusChip(
                        label: entity.distanceLabel,
                        icon: entity.isApproximate
                            ? Icons.location_searching_rounded
                            : Icons.near_me_outlined,
                        color: scheme.primary,
                      ),
                      AppStatusChip(
                        label: entity.semanticLabel,
                        icon: _icon(entity.type),
                        color: scheme.tertiary,
                      ),
                      if (entity.rating case final double rating
                          when rating > 0)
                        AppStatusChip(
                          label: rating.toStringAsFixed(1),
                          icon: Icons.star_rounded,
                          color: scheme.secondary,
                        ),
                      if (entity.distanceMeters case final int meters
                          when meters > 0)
                        AppStatusChip(
                          label: '${(meters / 1000).toStringAsFixed(1)} km',
                          icon: Icons.route_rounded,
                          color: scheme.secondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Open'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(NearbyEntityType type) => switch (type) {
    NearbyEntityType.place => Icons.place_outlined,
    NearbyEntityType.person => Icons.person_outline_rounded,
    NearbyEntityType.event => Icons.event_available_outlined,
    NearbyEntityType.route => Icons.route_outlined,
  };
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.entity});

  final NearbyEntity entity;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? imageUrl = entity.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 78,
        height: 78,
        child: imageUrl == null || imageUrl.isEmpty
            ? ColoredBox(
                color: scheme.primaryContainer,
                child: Icon(
                  NearbyResultCard._icon(entity.type),
                  color: scheme.onPrimaryContainer,
                  size: 34,
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (BuildContext _, String _) =>
                    ColoredBox(color: scheme.surfaceContainerHighest),
                errorWidget: (BuildContext _, String _, Object _) => ColoredBox(
                  color: scheme.primaryContainer,
                  child: Icon(
                    NearbyResultCard._icon(entity.type),
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
      ),
    );
  }
}
