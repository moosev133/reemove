import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/repositories/marketplace_catalog_repository.dart';
import '../dto/marketplace_listing_dto.dart';
import '../mappers/marketplace_listing_mapper.dart';

class FirebaseMarketplaceCatalogRepository
    implements MarketplaceCatalogRepository {
  const FirebaseMarketplaceCatalogRepository(this._listings);

  final CollectionReference<MarketplaceListingDto> _listings;

  @override
  Stream<Result<List<MarketplaceListing>>> watchLatest({
    String? sportId,
    int limit = 30,
  }) async* {
    try {
      Query<MarketplaceListingDto> query = _listings
          .where('status', isEqualTo: 'active')
          .where('moderationState', isEqualTo: 'active');
      if (sportId != null) {
        query = query.where('sportId', isEqualTo: sportId);
      }
      query = query.orderBy('createdAt', descending: true).limit(limit);
      await for (final QuerySnapshot<MarketplaceListingDto> snapshot
          in query.snapshots()) {
        yield Success<List<MarketplaceListing>>(
          snapshot.docs
              .map((doc) => doc.data().toDomain())
              .toList(growable: false),
        );
      }
    } catch (error) {
      yield FailureResult<List<MarketplaceListing>>(_mapError(error));
    }
  }

  @override
  Future<Result<MarketplaceListing?>> getById(String listingId) async {
    try {
      final DocumentSnapshot<MarketplaceListingDto> snapshot = await _listings
          .doc(listingId)
          .get();
      return Success<MarketplaceListing?>(snapshot.data()?.toDomain());
    } catch (error) {
      return FailureResult<MarketplaceListing?>(_mapError(error));
    }
  }

  static Failure _mapError(Object error) {
    if (error is FirebaseException) {
      return FirestoreFailureMapper.fromFirebaseException(error);
    }
    if (error is FormatException) {
      return FirestoreFailureMapper.fromFormatException(error);
    }
    return FirestoreFailureMapper.unexpected(error);
  }
}
