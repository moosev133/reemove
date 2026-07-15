import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../application/marketplace_catalog.dart';
import '../../application/marketplace_providers.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/marketplace_requests.dart';

class MarketplaceListingScreen extends ConsumerStatefulWidget {
  const MarketplaceListingScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<MarketplaceListingScreen> createState() =>
      _MarketplaceListingScreenState();
}

class _MarketplaceListingScreenState
    extends ConsumerState<MarketplaceListingScreen> {
  bool _recorded = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MarketplaceListing?> value = ref.watch(
      marketplaceListingProvider(widget.listingId),
    );
    final AuthUser? user = ref.watch(currentAuthUserProvider).value;
    final bool actionLoading = ref
        .watch(marketplaceActionControllerProvider)
        .isLoading;
    return value.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, _) => Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: Center(child: Text(error.toString())),
      ),
      data: (MarketplaceListing? listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Listing')),
            body: const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Listing unavailable',
              message: 'It may have been removed, expired, or moderated.',
            ),
          );
        }
        if (!_recorded && listing.sellerId != user?.uid) {
          _recorded = true;
          unawaited(
            Future<void>.microtask(
              () => ref
                  .read(marketplaceActionControllerProvider.notifier)
                  .recordView(listing.id),
            ),
          );
        }
        final bool owner = listing.sellerId == user?.uid;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Marketplace listing'),
            actions: <Widget>[
              if (!owner)
                IconButton(
                  tooltip: listing.isFavorited ? 'Remove favorite' : 'Save',
                  onPressed: actionLoading
                      ? null
                      : () => unawaited(
                          ref
                              .read(
                                marketplaceActionControllerProvider.notifier,
                              )
                              .toggleFavorite(listing),
                        ),
                  icon: Icon(
                    listing.isFavorited
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (String value) {
                  if (value == 'report') {
                    unawaited(_report(listing));
                  }
                  if (value == 'seller') {
                    unawaited(
                      context.push(
                        AppRoutes.marketplaceSeller(listing.sellerId),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'seller',
                    child: Text('View seller'),
                  ),
                  if (!owner)
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Text('Report listing'),
                    ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: owner
                  ? _OwnerActions(listing: listing)
                  : FilledButton.icon(
                      onPressed: actionLoading || !listing.canReceiveMessages
                          ? null
                          : () => _messageSeller(listing),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(
                        listing.status == ListingStatus.reserved
                            ? 'Ask about reserved item'
                            : 'Message seller',
                      ),
                    ),
            ),
          ),
          body: AdaptivePageBody(
            maxWidth: 980,
            slivers: <Widget>[
              _MediaGallery(listing: listing),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _money(listing),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          listing.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  AppStatusChip(
                    label: _statusLabel(listing.status),
                    icon: Icons.inventory_2_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  Chip(
                    label: Text(
                      MarketplaceCatalog.categoryLabel(listing.categoryId),
                    ),
                  ),
                  Chip(label: Text(_conditionLabel(listing.condition))),
                  if (listing.isNegotiable)
                    const Chip(label: Text('Negotiable')),
                  if (listing.distanceKm != null)
                    Chip(
                      label: Text(
                        '${listing.distanceKm!.toStringAsFixed(1)} km away',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(listing.description),
              const SizedBox(height: AppSpacing.xl),
              _DetailsPanel(listing: listing),
              const SizedBox(height: AppSpacing.lg),
              PremiumSurface(
                onTap: () =>
                    context.push(AppRoutes.marketplaceSeller(listing.sellerId)),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: listing.seller.avatarUrl == null
                          ? null
                          : NetworkImage(listing.seller.avatarUrl!),
                      child: listing.seller.avatarUrl == null
                          ? Text(
                              listing.seller.displayName.characters.first
                                  .toUpperCase(),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  listing.seller.displayName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              if (listing.seller.isVerified) ...<Widget>[
                                const SizedBox(width: AppSpacing.xs),
                                Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          Text('@${listing.seller.username}'),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumSurface(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.health_and_safety_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Text(
                        'Keep payment and personal details private. Meet in a busy public place, inspect equipment before paying, and report suspicious behavior. ReeMove does not process payments in this phase.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        );
      },
    );
  }

  Future<void> _messageSeller(MarketplaceListing listing) async {
    final Result<String> result = await ref
        .read(marketplaceActionControllerProvider.notifier)
        .startConversation(listing.id);
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (String conversationId) {
        unawaited(
          context.push(
            AppRoutes.conversationForListing(conversationId, listing.id),
          ),
        );
      },
      failure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _report(MarketplaceListing listing) async {
    final MarketplaceReportReason? reason =
        await showModalBottomSheet<MarketplaceReportReason>(
          context: context,
          showDragHandle: true,
          builder: (BuildContext context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: MarketplaceReportReason.values
                  .map(
                    (MarketplaceReportReason item) => ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(_humanizeEnumName(item.name)),
                      onTap: () => Navigator.pop(context, item),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
    if (reason == null) {
      return;
    }
    final bool sent = await ref
        .read(marketplaceActionControllerProvider.notifier)
        .report(listingId: listing.id, reason: reason);
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted for review.')),
      );
    }
  }

  static String _money(MarketplaceListing listing) {
    final String amount = listing.price.amountMajor % 1 == 0
        ? listing.price.amountMajor.toStringAsFixed(0)
        : listing.price.amountMajor.toStringAsFixed(2);
    final String symbol = switch (listing.price.currency) {
      'ILS' => '₪',
      'USD' => r'$',
      'EUR' => '€',
      _ => '${listing.price.currency} ',
    };
    return '$symbol$amount';
  }

  static String _humanizeEnumName(String value) => value
      .replaceAllMapped(
        RegExp(r'([A-Z])'),
        (Match match) => ' ${match.group(1)}',
      )
      .trim();

  static String _statusLabel(ListingStatus value) => switch (value) {
    ListingStatus.draft => 'Draft',
    ListingStatus.pendingReview => 'In review',
    ListingStatus.active => 'Available',
    ListingStatus.paused => 'Paused',
    ListingStatus.reserved => 'Reserved',
    ListingStatus.sold => 'Sold',
    ListingStatus.expired => 'Expired',
    ListingStatus.removed => 'Removed',
    ListingStatus.rejected => 'Needs changes',
  };

  static String _conditionLabel(ListingCondition value) => switch (value) {
    ListingCondition.newItem => 'New',
    ListingCondition.likeNew => 'Like new',
    ListingCondition.good => 'Good condition',
    ListingCondition.fair => 'Fair condition',
    ListingCondition.poor => 'Well used',
  };
}

class _MediaGallery extends StatelessWidget {
  const _MediaGallery({required this.listing});

  final MarketplaceListing listing;

  @override
  Widget build(BuildContext context) {
    if (listing.media.isEmpty) {
      return const AspectRatio(
        aspectRatio: 16 / 10,
        child: PremiumSurface(
          child: Center(
            child: Icon(Icons.image_not_supported_outlined, size: 54),
          ),
        ),
      );
    }
    return SizedBox(
      height: 460,
      child: PageView.builder(
        itemCount: listing.media.length,
        itemBuilder: (BuildContext context, int index) {
          final String? url = listing.media[index].downloadUrl;
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: url == null
                ? const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.image_outlined, size: 54),
                  )
                : Image.network(url, fit: BoxFit.cover),
          );
        },
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.listing});

  final MarketplaceListing listing;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: Column(
        children: <Widget>[
          _row(
            context,
            Icons.sports_outlined,
            'Sport',
            MarketplaceCatalog.sportLabels[listing.sportId] ?? listing.sportId,
          ),
          const Divider(height: AppSpacing.xl),
          _row(
            context,
            Icons.location_on_outlined,
            'Pickup area',
            listing.location.locality ?? 'Approximate public area',
          ),
          const Divider(height: AppSpacing.xl),
          _row(
            context,
            Icons.local_shipping_outlined,
            'Delivery',
            listing.deliveryOptions.map((item) => item.name).join(', '),
          ),
          const Divider(height: AppSpacing.xl),
          _row(
            context,
            Icons.visibility_outlined,
            'Views',
            '${listing.viewCount}',
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: <Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _OwnerActions extends ConsumerWidget {
  const _OwnerActions({required this.listing});

  final MarketplaceListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MarketplaceListingAction? primaryAction = switch (listing.status) {
      ListingStatus.active => MarketplaceListingAction.reserve,
      ListingStatus.paused => MarketplaceListingAction.activate,
      ListingStatus.reserved => MarketplaceListingAction.sold,
      ListingStatus.expired => MarketplaceListingAction.activate,
      _ => null,
    };
    final MarketplaceListingAction? secondaryAction = switch (listing.status) {
      ListingStatus.active => MarketplaceListingAction.pause,
      ListingStatus.reserved => MarketplaceListingAction.activate,
      ListingStatus.paused ||
      ListingStatus.expired => MarketplaceListingAction.remove,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: listing.canEditBySeller
                    ? () => context.push(
                        AppRoutes.editMarketplaceListing(listing.id),
                      )
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: primaryAction == null
                    ? null
                    : () => ref
                          .read(marketplaceActionControllerProvider.notifier)
                          .changeStatus(listing.id, primaryAction),
                icon: Icon(
                  primaryAction == MarketplaceListingAction.sold
                      ? Icons.check_circle_outline_rounded
                      : Icons.inventory_2_outlined,
                ),
                label: Text(switch (primaryAction) {
                  MarketplaceListingAction.reserve => 'Mark reserved',
                  MarketplaceListingAction.sold => 'Mark sold',
                  MarketplaceListingAction.activate
                      when listing.status == ListingStatus.paused =>
                    'Reactivate',
                  MarketplaceListingAction.activate => 'Relist',
                  _ => 'Unavailable',
                }),
              ),
            ),
          ],
        ),
        if (secondaryAction != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => ref
                .read(marketplaceActionControllerProvider.notifier)
                .changeStatus(listing.id, secondaryAction),
            icon: Icon(
              secondaryAction == MarketplaceListingAction.remove
                  ? Icons.delete_outline_rounded
                  : secondaryAction == MarketplaceListingAction.pause
                  ? Icons.pause_circle_outline_rounded
                  : Icons.inventory_2_outlined,
            ),
            label: Text(switch (secondaryAction) {
              MarketplaceListingAction.pause => 'Pause listing',
              MarketplaceListingAction.activate => 'Make available again',
              MarketplaceListingAction.remove => 'Remove listing',
              _ => 'Update listing',
            }),
          ),
        ],
      ],
    );
  }
}
