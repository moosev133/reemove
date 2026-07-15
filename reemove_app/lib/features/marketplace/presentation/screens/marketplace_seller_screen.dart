import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/marketplace_providers.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/marketplace_seller.dart';
import '../widgets/marketplace_listing_card.dart';

class MarketplaceSellerScreen extends ConsumerStatefulWidget {
  const MarketplaceSellerScreen({required this.sellerId, super.key});

  final String sellerId;

  @override
  ConsumerState<MarketplaceSellerScreen> createState() =>
      _MarketplaceSellerScreenState();
}

class _MarketplaceSellerScreenState
    extends ConsumerState<MarketplaceSellerScreen> {
  List<MarketplaceListing> _listings = const <MarketplaceListing>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final Result<MarketplacePage> result = await ref
        .read(marketplaceRepositoryProvider)
        .loadSellerListings(sellerId: widget.sellerId);
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (MarketplacePage page) => setState(() {
        _listings = page.items;
        _loading = false;
      }),
      failure: (Failure failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MarketplaceSellerProfile> sellerValue = ref.watch(
      marketplaceSellerProvider(widget.sellerId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Seller profile')),
      body: sellerValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => Center(child: Text(error.toString())),
        data: (MarketplaceSellerProfile seller) => RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: AdaptivePageBody(
                  slivers: <Widget>[
                    PremiumSurface(
                      child: Column(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 46,
                            backgroundImage: seller.avatarUrl == null
                                ? null
                                : NetworkImage(seller.avatarUrl!),
                            child: seller.avatarUrl == null
                                ? Text(
                                    seller.displayName.characters.first
                                        .toUpperCase(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  )
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  seller.displayName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              ),
                              if (seller.isVerified) ...<Widget>[
                                const SizedBox(width: AppSpacing.xs),
                                Icon(
                                  Icons.verified_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          Text('@${seller.username}'),
                          if (seller.locality != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(seller.locality!),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              _Stat(
                                label: 'Active',
                                value: seller.activeListingCount,
                              ),
                              _Stat(
                                label: 'Sold',
                                value: seller.soldListingCount,
                              ),
                              _Stat(
                                label: 'Member since',
                                valueText: seller.memberSince.year.toString(),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            onPressed: seller.username.isEmpty
                                ? null
                                : () => context.push(
                                    AppRoutes.publicProfile(seller.username),
                                  ),
                            icon: const Icon(Icons.person_outline_rounded),
                            label: const Text('View ReeMove profile'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Listings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_error != null)
                      AppEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load listings',
                        message: _error!,
                        actionLabel: 'Retry',
                        onAction: _load,
                      )
                    else if (_loading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
              if (!_loading && _error == null && _listings.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No active listings',
                    message:
                        'This seller has no public marketplace items right now.',
                  ),
                )
              else if (_listings.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.69,
                        ),
                    itemCount: _listings.length,
                    itemBuilder: (BuildContext context, int index) {
                      final MarketplaceListing listing = _listings[index];
                      return MarketplaceListingCard(
                        listing: listing,
                        compact: true,
                        onTap: () => context.push(
                          AppRoutes.marketplaceListing(listing.id),
                        ),
                        onFavorite: () => ref
                            .read(marketplaceActionControllerProvider.notifier)
                            .toggleFavorite(listing),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, this.value, this.valueText});

  final String label;
  final int? value;
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          valueText ?? '${value ?? 0}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
