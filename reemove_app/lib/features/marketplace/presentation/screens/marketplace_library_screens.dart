import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../application/marketplace_providers.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/marketplace_requests.dart';
import '../widgets/marketplace_listing_card.dart';

class MarketplaceFavoritesScreen extends ConsumerStatefulWidget {
  const MarketplaceFavoritesScreen({super.key});

  @override
  ConsumerState<MarketplaceFavoritesScreen> createState() =>
      _MarketplaceFavoritesScreenState();
}

class _MarketplaceFavoritesScreenState
    extends ConsumerState<MarketplaceFavoritesScreen> {
  List<MarketplaceListing> _items = const <MarketplaceListing>[];
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
        .loadFavorites();
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (MarketplacePage page) => setState(() {
        _items = page.items;
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
    return _MarketplaceLibraryScaffold(
      title: 'Saved listings',
      loading: _loading,
      error: _error,
      items: _items,
      emptyTitle: 'No saved listings',
      emptyMessage: 'Tap the heart on a marketplace item to keep it here.',
      onRefresh: _load,
      onFavorite: (MarketplaceListing listing) async {
        await ref
            .read(marketplaceActionControllerProvider.notifier)
            .toggleFavorite(listing);
        await _load();
      },
    );
  }
}

class MyMarketplaceListingsScreen extends ConsumerStatefulWidget {
  const MyMarketplaceListingsScreen({super.key});

  @override
  ConsumerState<MyMarketplaceListingsScreen> createState() =>
      _MyMarketplaceListingsScreenState();
}

class _MyMarketplaceListingsScreenState
    extends ConsumerState<MyMarketplaceListingsScreen> {
  List<MarketplaceListing> _items = const <MarketplaceListing>[];
  ListingStatus? _status;
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
        .loadMyListings(status: _status);
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (MarketplacePage page) => setState(() {
        _items = page.items;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My listings'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Create listing',
            onPressed: () => context.push(AppRoutes.createMarketplaceListing),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: _status == null,
                  onSelected: (_) {
                    setState(() => _status = null);
                    unawaited(_load());
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                ...<ListingStatus>[
                  ListingStatus.draft,
                  ListingStatus.active,
                  ListingStatus.paused,
                  ListingStatus.reserved,
                  ListingStatus.sold,
                  ListingStatus.expired,
                  ListingStatus.removed,
                  ListingStatus.rejected,
                ].map(
                  (ListingStatus status) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(_label(status)),
                      selected: _status == status,
                      onSelected: (_) {
                        setState(() => _status = status);
                        unawaited(_load());
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _MarketplaceLibraryScaffold(
              embedded: true,
              title: 'My listings',
              loading: _loading,
              error: _error,
              items: _items,
              emptyTitle: 'No listings in this state',
              emptyMessage: 'Create a listing or choose another status.',
              onRefresh: _load,
              onFavorite: (_) async {},
              ownerActions: true,
              onChanged: _load,
            ),
          ),
        ],
      ),
    );
  }

  static String _label(ListingStatus status) => switch (status) {
    ListingStatus.draft => 'Drafts',
    ListingStatus.active => 'Active',
    ListingStatus.paused => 'Paused',
    ListingStatus.reserved => 'Reserved',
    ListingStatus.sold => 'Sold',
    ListingStatus.expired => 'Expired',
    ListingStatus.removed => 'Removed',
    ListingStatus.rejected => 'Needs changes',
    ListingStatus.pendingReview => 'In review',
  };
}

class _MarketplaceLibraryScaffold extends ConsumerWidget {
  const _MarketplaceLibraryScaffold({
    required this.title,
    required this.loading,
    required this.error,
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onFavorite,
    this.embedded = false,
    this.ownerActions = false,
    this.onChanged,
  });

  final String title;
  final bool loading;
  final String? error;
  final List<MarketplaceListing> items;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function(MarketplaceListing listing) onFavorite;
  final bool embedded;
  final bool ownerActions;
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget content = RefreshIndicator(
      onRefresh: onRefresh,
      child: loading
          ? ListView(
              children: <Widget>[
                const SizedBox(height: 260),
                const Center(child: CircularProgressIndicator()),
              ],
            )
          : error != null
          ? ListView(
              children: <Widget>[
                const SizedBox(height: 120),
                AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load listings',
                  message: error!,
                  actionLabel: 'Retry',
                  onAction: onRefresh,
                ),
              ],
            )
          : items.isEmpty
          ? ListView(
              children: <Widget>[
                const SizedBox(height: 120),
                AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: emptyTitle,
                  message: emptyMessage,
                ),
              ],
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final MarketplaceListing listing = items[index];
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: MarketplaceListingCard(
                        listing: listing,
                        compact: true,
                        onTap: () => context.push(
                          AppRoutes.marketplaceListing(listing.id),
                        ),
                        onFavorite: ownerActions
                            ? () {}
                            : () => onFavorite(listing),
                      ),
                    ),
                    if (ownerActions) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: listing.canEditBySeller
                                  ? () => context.push(
                                      AppRoutes.editMarketplaceListing(
                                        listing.id,
                                      ),
                                    )
                                  : null,
                              child: const Text('Edit'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton(
                              onPressed: _action(listing) == null
                                  ? null
                                  : () async {
                                      await ref
                                          .read(
                                            marketplaceActionControllerProvider
                                                .notifier,
                                          )
                                          .changeStatus(
                                            listing.id,
                                            _action(listing)!,
                                          );
                                      await onChanged?.call();
                                    },
                              child: Text(_actionLabel(listing)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
    );
    if (embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: content,
    );
  }

  static MarketplaceListingAction? _action(MarketplaceListing listing) =>
      switch (listing.status) {
        ListingStatus.active => MarketplaceListingAction.reserve,
        ListingStatus.paused => MarketplaceListingAction.activate,
        ListingStatus.reserved => MarketplaceListingAction.sold,
        ListingStatus.expired => MarketplaceListingAction.activate,
        ListingStatus.draft || ListingStatus.rejected => null,
        _ => MarketplaceListingAction.remove,
      };

  static String _actionLabel(MarketplaceListing listing) =>
      switch (_action(listing)) {
        MarketplaceListingAction.reserve => 'Reserve',
        MarketplaceListingAction.sold => 'Sold',
        MarketplaceListingAction.activate =>
          listing.status == ListingStatus.paused ? 'Reactivate' : 'Relist',
        MarketplaceListingAction.pause => 'Pause',
        MarketplaceListingAction.remove => 'Remove',
        null => 'Publish',
      };
}
