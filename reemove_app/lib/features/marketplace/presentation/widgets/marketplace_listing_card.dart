import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/marketplace_catalog.dart';
import '../../domain/entities/marketplace_listing.dart';

class MarketplaceListingCard extends StatelessWidget {
  const MarketplaceListingCard({
    required this.listing,
    required this.onTap,
    required this.onFavorite,
    this.compact = false,
    super.key,
  });

  final MarketplaceListing listing;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = listing.media.isEmpty
        ? null
        : listing.media.first.thumbnailUrl ?? listing.media.first.downloadUrl;
    return PremiumSurface(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: compact ? 1.25 : 1.18,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (imageUrl == null)
                    ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(
                        Icons.sports_basketball_outlined,
                        size: 48,
                      ),
                    )
                  else
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 42,
                        ),
                      ),
                    ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: listing.isFavorited
                            ? 'Remove from favorites'
                            : 'Save listing',
                        onPressed: onFavorite,
                        icon: Icon(
                          listing.isFavorited
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: listing.isFavorited
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (listing.status == ListingStatus.reserved)
                    Positioned(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: _Badge(label: 'Reserved'),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _money(listing),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${MarketplaceCatalog.categoryLabel(listing.categoryId)} · ${_conditionLabel(listing.condition)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        listing.distanceKm == null
                            ? listing.location.locality ??
                                  'Approximate pickup area'
                            : '${listing.distanceKm!.toStringAsFixed(1)} km away',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (listing.isNegotiable) const _Badge(label: 'Negotiable'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _money(MarketplaceListing listing) {
    final String amount = listing.price.amountMajor % 1 == 0
        ? listing.price.amountMajor.toStringAsFixed(0)
        : listing.price.amountMajor.toStringAsFixed(2);
    final String symbol = switch (listing.price.currency) {
      'ILS' => '₪',
      'USD' => r'$',
      'EUR' => '€',
      _ => listing.price.currency,
    };
    return '$symbol$amount';
  }

  static String _conditionLabel(ListingCondition condition) =>
      switch (condition) {
        ListingCondition.newItem => 'New',
        ListingCondition.likeNew => 'Like new',
        ListingCondition.good => 'Good',
        ListingCondition.fair => 'Fair',
        ListingCondition.poor => 'Well used',
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
