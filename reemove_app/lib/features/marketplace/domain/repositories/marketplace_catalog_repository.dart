import '../../../../core/result/result.dart';
import '../entities/marketplace_listing.dart';
import '../entities/marketplace_requests.dart';
import '../entities/marketplace_seller.dart';

abstract interface class MarketplaceCatalogRepository {
  Future<Result<MarketplacePage>> search({
    required MarketplaceSearchFilters filters,
    String? cursor,
    int limit = 24,
  });

  Stream<Result<MarketplaceListing?>> watchListing(String listingId);

  Future<Result<MarketplacePage>> loadSellerListings({
    required String sellerId,
    ListingStatus? status,
    String? cursor,
    int limit = 24,
  });

  Future<Result<MarketplacePage>> loadFavorites({
    String? cursor,
    int limit = 24,
  });

  Future<Result<MarketplacePage>> loadMyListings({
    ListingStatus? status,
    String? cursor,
    int limit = 24,
  });

  Future<Result<MarketplaceSellerProfile>> loadSeller(String sellerId);

  Stream<Result<Set<String>>> watchFavoriteIds();

  Stream<Result<bool>> watchFavorite(String listingId);

  Future<Result<String>> createDraft(MarketplaceListingDraft draft);

  Future<Result<void>> saveDraft(MarketplaceListingDraft draft);

  Future<Result<void>> publish(String listingId);

  Future<Result<void>> changeStatus({
    required String listingId,
    required MarketplaceListingAction action,
  });

  Future<Result<bool>> toggleFavorite(String listingId);

  Future<Result<void>> recordView(String listingId);

  Future<Result<void>> report({
    required String listingId,
    required MarketplaceReportReason reason,
    String details = '',
  });

  Future<Result<String>> startConversation(String listingId);
}
