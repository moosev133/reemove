import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/result/result.dart';
import '../data/repositories/firebase_marketplace_catalog_repository.dart';
import '../data/repositories/firebase_marketplace_media_repository.dart';
import '../data/services/platform_marketplace_media_picker.dart';
import '../domain/entities/marketplace_listing.dart';
import '../domain/entities/marketplace_requests.dart';
import '../domain/entities/marketplace_seller.dart';
import '../domain/repositories/marketplace_catalog_repository.dart';
import '../domain/repositories/marketplace_media_repository.dart';
import '../domain/services/marketplace_media_picker.dart';

final Provider<MarketplaceCatalogRepository> marketplaceRepositoryProvider =
    Provider<MarketplaceCatalogRepository>((Ref ref) {
      return FirebaseMarketplaceCatalogRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
        auth: ref.watch(firebaseAuthProvider),
      );
    });

final Provider<MarketplaceMediaRepository> marketplaceMediaRepositoryProvider =
    Provider<MarketplaceMediaRepository>((Ref ref) {
      return FirebaseMarketplaceMediaRepository(
        storage: ref.watch(firebaseStorageProvider),
        auth: ref.watch(firebaseAuthProvider),
      );
    });

final Provider<MarketplaceMediaPicker> marketplaceMediaPickerProvider =
    Provider<MarketplaceMediaPicker>((Ref ref) {
      return PlatformMarketplaceMediaPicker(ImagePicker());
    });

final marketplaceFavoriteIdsProvider = StreamProvider<Set<String>>((
  Ref ref,
) async* {
  await for (final Result<Set<String>> result
      in ref.watch(marketplaceRepositoryProvider).watchFavoriteIds()) {
    yield _value(result);
  }
});

final marketplaceFavoriteProvider = StreamProvider.family<bool, String>((
  Ref ref,
  String listingId,
) async* {
  await for (final Result<bool> result
      in ref.watch(marketplaceRepositoryProvider).watchFavorite(listingId)) {
    yield _value(result);
  }
});

final marketplaceListingProvider =
    StreamProvider.family<MarketplaceListing?, String>((
      Ref ref,
      String listingId,
    ) async* {
      await for (final Result<MarketplaceListing?> result
          in ref.watch(marketplaceRepositoryProvider).watchListing(listingId)) {
        final MarketplaceListing? listing = _value(result);
        final bool isFavorite =
            ref.watch(marketplaceFavoriteProvider(listingId)).value ?? false;
        yield listing?.copyWith(isFavorited: isFavorite);
      }
    });

final marketplaceSellerProvider =
    FutureProvider.family<MarketplaceSellerProfile, String>((
      Ref ref,
      String sellerId,
    ) async {
      return _value(
        await ref.watch(marketplaceRepositoryProvider).loadSeller(sellerId),
      );
    });

final marketplaceCatalogControllerProvider =
    NotifierProvider<MarketplaceCatalogController, MarketplaceCatalogState>(
      MarketplaceCatalogController.new,
    );

final marketplaceActionControllerProvider =
    NotifierProvider<MarketplaceActionController, AsyncValue<void>>(
      MarketplaceActionController.new,
    );

class MarketplaceCatalogState {
  const MarketplaceCatalogState({
    this.filters = const MarketplaceSearchFilters(),
    this.items = const <MarketplaceListing>[],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final MarketplaceSearchFilters filters;
  final List<MarketplaceListing> items;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  MarketplaceCatalogState copyWith({
    MarketplaceSearchFilters? filters,
    List<MarketplaceListing>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MarketplaceCatalogState(
      filters: filters ?? this.filters,
      items: items ?? this.items,
      nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class MarketplaceCatalogController extends Notifier<MarketplaceCatalogState> {
  @override
  MarketplaceCatalogState build() => const MarketplaceCatalogState();

  Future<void> initialize({String? sportId}) async {
    if (state.items.isNotEmpty && state.filters.sportId == sportId) {
      return;
    }
    state = state.copyWith(
      filters: state.filters.copyWith(
        sportId: sportId,
        clearSport: sportId == null,
      ),
    );
    await refresh();
  }

  Future<void> setFilters(MarketplaceSearchFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      items: const <MarketplaceListing>[],
    );
    final Result<MarketplacePage> result = await ref
        .read(marketplaceRepositoryProvider)
        .search(filters: state.filters);
    result.when<void>(
      success: (MarketplacePage page) {
        final Set<String> favorites =
            ref.read(marketplaceFavoriteIdsProvider).value ?? const <String>{};
        state = state.copyWith(
          items: _applyFavorites(page.items, favorites),
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          isLoading: false,
        );
      },
      failure: (Failure failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.nextCursor == null) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearError: true);
    final Result<MarketplacePage> result = await ref
        .read(marketplaceRepositoryProvider)
        .search(filters: state.filters, cursor: state.nextCursor);
    result.when<void>(
      success: (MarketplacePage page) {
        final Set<String> favorites =
            ref.read(marketplaceFavoriteIdsProvider).value ?? const <String>{};
        state = state.copyWith(
          items: <MarketplaceListing>[
            ...state.items,
            ..._applyFavorites(page.items, favorites),
          ],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          isLoadingMore: false,
        );
      },
      failure: (Failure failure) {
        state = state.copyWith(
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
    );
  }

  void applyFavorite(String listingId, bool value) {
    state = state.copyWith(
      items: state.items
          .map((MarketplaceListing item) {
            if (item.id != listingId) {
              return item;
            }
            final int next = (item.favoriteCount + (value ? 1 : -1))
                .clamp(0, 1 << 30)
                .toInt();
            return item.copyWith(isFavorited: value, favoriteCount: next);
          })
          .toList(growable: false),
    );
  }

  static List<MarketplaceListing> _applyFavorites(
    List<MarketplaceListing> items,
    Set<String> favorites,
  ) => items
      .map(
        (MarketplaceListing item) => item.copyWith(
          isFavorited: item.isFavorited || favorites.contains(item.id),
        ),
      )
      .toList(growable: false);
}

class MarketplaceActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  Future<Result<String>> createDraft(MarketplaceListingDraft draft) =>
      ref.read(marketplaceRepositoryProvider).createDraft(draft);

  Future<bool> saveDraft(MarketplaceListingDraft draft) => _run(
    () => ref.read(marketplaceRepositoryProvider).saveDraft(draft),
    refreshCatalog: false,
  );

  Future<bool> publish(String listingId) => _run(
    () => ref.read(marketplaceRepositoryProvider).publish(listingId),
    invalidateListingId: listingId,
  );

  Future<bool> changeStatus(
    String listingId,
    MarketplaceListingAction action,
  ) => _run(
    () => ref
        .read(marketplaceRepositoryProvider)
        .changeStatus(listingId: listingId, action: action),
    invalidateListingId: listingId,
  );

  Future<bool> toggleFavorite(MarketplaceListing listing) async {
    final bool optimistic = !listing.isFavorited;
    ref
        .read(marketplaceCatalogControllerProvider.notifier)
        .applyFavorite(listing.id, optimistic);
    final Result<bool> result = await ref
        .read(marketplaceRepositoryProvider)
        .toggleFavorite(listing.id);
    return result.when<bool>(
      success: (bool value) {
        ref.invalidate(marketplaceFavoriteIdsProvider);
        ref.invalidate(marketplaceFavoriteProvider(listing.id));
        ref.invalidate(marketplaceListingProvider(listing.id));
        return value;
      },
      failure: (Failure failure) {
        ref
            .read(marketplaceCatalogControllerProvider.notifier)
            .applyFavorite(listing.id, listing.isFavorited);
        state = AsyncValue<void>.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> report({
    required String listingId,
    required MarketplaceReportReason reason,
    String details = '',
  }) => _run(
    () => ref
        .read(marketplaceRepositoryProvider)
        .report(listingId: listingId, reason: reason, details: details),
  );

  Future<Result<String>> startConversation(String listingId) =>
      ref.read(marketplaceRepositoryProvider).startConversation(listingId);

  Future<void> recordView(String listingId) async {
    await ref.read(marketplaceRepositoryProvider).recordView(listingId);
  }

  Future<bool> _run(
    Future<Result<void>> Function() action, {
    String? invalidateListingId,
    bool refreshCatalog = true,
  }) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await action();
    return result.when<bool>(
      success: (_) {
        state = const AsyncValue<void>.data(null);
        if (refreshCatalog) {
          unawaited(
            ref.read(marketplaceCatalogControllerProvider.notifier).refresh(),
          );
        }
        if (invalidateListingId != null) {
          ref.invalidate(marketplaceListingProvider(invalidateListingId));
        }
        return true;
      },
      failure: (Failure failure) {
        state = AsyncValue<void>.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }
}

T _value<T>(Result<T> result) => result.when<T>(
  success: (T value) => value,
  failure: (Failure failure) => throw StateError(failure.message),
);
