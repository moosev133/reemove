import '../../../../core/result/result.dart';
import '../entities/marketplace_listing.dart';

abstract interface class MarketplaceCatalogRepository {
  Stream<Result<List<MarketplaceListing>>> watchLatest({
    String? sportId,
    int limit = 30,
  });
  Future<Result<MarketplaceListing?>> getById(String listingId);
}
