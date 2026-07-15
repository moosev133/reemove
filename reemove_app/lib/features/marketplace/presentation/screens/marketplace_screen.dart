import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../application/marketplace_providers.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../widgets/marketplace_filter_sheet.dart';
import '../widgets/marketplace_listing_card.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({this.sportId, super.key});

  final String? sportId;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(Future<void>.microtask(_initialize));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final UserProfile? profile = ref.read(currentUserProfileProvider).value;
    final MarketplaceCatalogController controller = ref.read(
      marketplaceCatalogControllerProvider.notifier,
    );
    await controller.initialize(sportId: widget.sportId);
    final MarketplaceCatalogState current = ref.read(
      marketplaceCatalogControllerProvider,
    );
    if (profile?.location != null) {
      await controller.setFilters(
        current.filters.copyWith(
          latitude: profile!.location!.latitude,
          longitude: profile.location!.longitude,
          radiusKm: profile.discoveryRadiusKm.clamp(1, 100).toDouble(),
        ),
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 650) {
      unawaited(
        ref.read(marketplaceCatalogControllerProvider.notifier).loadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final MarketplaceCatalogState state = ref.watch(
      marketplaceCatalogControllerProvider,
    );
    final bool actionLoading = ref
        .watch(marketplaceActionControllerProvider)
        .isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Favorites',
            onPressed: () => context.push(AppRoutes.marketplaceFavorites),
            icon: const Icon(Icons.favorite_border_rounded),
          ),
          IconButton(
            tooltip: 'My listings',
            onPressed: () => context.push(AppRoutes.myMarketplaceListings),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: actionLoading
            ? null
            : () => context.push(AppRoutes.createMarketplaceListing),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Sell item'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(marketplaceCatalogControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: AdaptivePageBody(
                slivers: <Widget>[
                  const AppPageHeader(
                    eyebrow: 'Sports equipment from the community',
                    title: 'Buy and sell with confidence',
                    subtitle:
                        'Search equipment, inspect seller profiles, save favorites, and continue safely in ReeMove chat.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SearchBar(
                    controller: _searchController,
                    hintText: 'Search balls, weights, shoes, watches…',
                    leading: const Icon(Icons.search_rounded),
                    trailing: <Widget>[
                      IconButton(
                        tooltip: 'Filters',
                        onPressed: () => _showFilters(state.filters),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                    onChanged: _searchChanged,
                    onSubmitted: (_) => _applySearch(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ActiveFilterSummary(filters: state.filters),
                  if (state.errorMessage != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    MaterialBanner(
                      content: Text(state.errorMessage!),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => ref
                              .read(
                                marketplaceCatalogControllerProvider.notifier,
                              )
                              .refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
            if (state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matching listings',
                  message:
                      'Try a broader search, adjust the price or distance, or create the first listing in this category.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _searchController.clear();
                    unawaited(
                      ref
                          .read(marketplaceCatalogControllerProvider.notifier)
                          .setFilters(const MarketplaceSearchFilters()),
                    );
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  120,
                ),
                sliver: SliverLayoutBuilder(
                  builder:
                      (BuildContext context, SliverConstraints constraints) {
                        final int count = constraints.crossAxisExtent >= 1100
                            ? 4
                            : constraints.crossAxisExtent >= 760
                            ? 3
                            : constraints.crossAxisExtent >= 520
                            ? 2
                            : 1;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: count,
                                mainAxisSpacing: AppSpacing.md,
                                crossAxisSpacing: AppSpacing.md,
                                childAspectRatio: count == 1 ? 1.25 : 0.68,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            BuildContext context,
                            int index,
                          ) {
                            final MarketplaceListing listing =
                                state.items[index];
                            return MarketplaceListingCard(
                              listing: listing,
                              compact: count > 1,
                              onTap: () => context.push(
                                AppRoutes.marketplaceListing(listing.id),
                              ),
                              onFavorite: () => ref
                                  .read(
                                    marketplaceActionControllerProvider
                                        .notifier,
                                  )
                                  .toggleFavorite(listing),
                            );
                          }, childCount: state.items.length),
                        );
                      },
                ),
              ),
            if (state.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _applySearch);
  }

  void _applySearch() {
    final MarketplaceCatalogState state = ref.read(
      marketplaceCatalogControllerProvider,
    );
    unawaited(
      ref
          .read(marketplaceCatalogControllerProvider.notifier)
          .setFilters(
            state.filters.copyWith(query: _searchController.text.trim()),
          ),
    );
  }

  Future<void> _showFilters(MarketplaceSearchFilters current) async {
    final MarketplaceSearchFilters? result =
        await showModalBottomSheet<MarketplaceSearchFilters>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (BuildContext context) =>
              MarketplaceFilterSheet(initial: current),
        );
    if (result != null) {
      await ref
          .read(marketplaceCatalogControllerProvider.notifier)
          .setFilters(result.copyWith(query: _searchController.text.trim()));
    }
  }
}

class _ActiveFilterSummary extends StatelessWidget {
  const _ActiveFilterSummary({required this.filters});

  final MarketplaceSearchFilters filters;

  @override
  Widget build(BuildContext context) {
    final List<String> labels = <String>[
      if (filters.sportId != null) filters.sportId!,
      if (filters.categoryId != null) filters.categoryId!.replaceAll('_', ' '),
      if (filters.condition != null) filters.condition!.name,
      if (filters.minimumPriceMinor != null ||
          filters.maximumPriceMinor != null)
        'price range',
      if (filters.deliveryOptions.isNotEmpty) 'delivery',
      if (filters.sort != MarketplaceSort.newest) filters.sort.name,
      if (filters.usesLocation) '${filters.radiusKm.toStringAsFixed(0)} km',
    ];
    if (labels.isEmpty) {
      return Text(
        'Newest active listings',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: labels
          .map(
            (String label) =>
                Chip(visualDensity: VisualDensity.compact, label: Text(label)),
          )
          .toList(growable: false),
    );
  }
}
