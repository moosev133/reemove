import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../application/marketplace_providers.dart';
import '../../domain/entities/marketplace_listing.dart';

class MarketplaceConversationBanner extends ConsumerWidget {
  const MarketplaceConversationBanner({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MarketplaceListing?> value = ref.watch(
      marketplaceListingProvider(listingId),
    );
    final MarketplaceListing? listing = value.value;
    if (listing == null) {
      return const SizedBox.shrink();
    }
    final String? imageUrl = listing.media.isEmpty
        ? null
        : listing.media.first.thumbnailUrl ?? listing.media.first.downloadUrl;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => context.push(AppRoutes.marketplaceListing(listing.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: imageUrl == null
                      ? const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.inventory_2_outlined),
                        )
                      : Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${listing.price.currency} ${listing.price.amountMajor.toStringAsFixed(0)} · ${listing.status.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
