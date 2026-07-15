import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/database/firestore_parser.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/marketplace_requests.dart';
import '../../domain/entities/marketplace_seller.dart';
import '../../domain/repositories/marketplace_catalog_repository.dart';
import '../dto/marketplace_listing_dto.dart';
import '../mappers/marketplace_listing_mapper.dart';
import '../services/marketplace_failure_mapper.dart';

class FirebaseMarketplaceCatalogRepository
    implements MarketplaceCatalogRepository {
  const FirebaseMarketplaceCatalogRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _functions = functions,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  CollectionReference<MarketplaceListingDto> get _listings => _firestore
      .collection('marketplace_listings')
      .withConverter<MarketplaceListingDto>(
        fromFirestore: MarketplaceListingDto.fromFirestore,
        toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
      );

  @override
  Future<Result<MarketplacePage>> search({
    required MarketplaceSearchFilters filters,
    String? cursor,
    int limit = 24,
  }) async {
    return _pageCall('searchMarketplace', <String, Object?>{
      'query': filters.query,
      if (filters.sportId != null) 'sportId': filters.sportId,
      if (filters.categoryId != null) 'categoryId': filters.categoryId,
      if (filters.condition != null) 'condition': filters.condition!.name,
      if (filters.minimumPriceMinor != null)
        'minimumPriceMinor': filters.minimumPriceMinor,
      if (filters.maximumPriceMinor != null)
        'maximumPriceMinor': filters.maximumPriceMinor,
      'deliveryOptions': filters.deliveryOptions
          .map((MarketplaceDeliveryOption item) => item.name)
          .toList(growable: false),
      'sort': filters.sort.name,
      if (filters.latitude != null) 'latitude': filters.latitude,
      if (filters.longitude != null) 'longitude': filters.longitude,
      'radiusKm': filters.radiusKm,
      'cursor': ?cursor,
      'limit': limit.clamp(1, 40),
    });
  }

  @override
  Stream<Result<MarketplaceListing?>> watchListing(String listingId) async* {
    try {
      await for (final DocumentSnapshot<MarketplaceListingDto> snapshot
          in _listings.doc(listingId).snapshots()) {
        yield Success<MarketplaceListing?>(snapshot.data()?.toDomain());
      }
    } on FirebaseException catch (error) {
      yield FailureResult<MarketplaceListing?>(
        MarketplaceFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<MarketplaceListing?>(
        MarketplaceFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<MarketplacePage>> loadSellerListings({
    required String sellerId,
    ListingStatus? status,
    String? cursor,
    int limit = 24,
  }) {
    return _pageCall('loadMarketplaceSellerListings', <String, Object?>{
      'sellerId': sellerId,
      if (status != null) 'status': status.name,
      'cursor': ?cursor,
      'limit': limit.clamp(1, 40),
    });
  }

  @override
  Future<Result<MarketplacePage>> loadFavorites({
    String? cursor,
    int limit = 24,
  }) {
    return _pageCall('loadMarketplaceFavorites', <String, Object?>{
      'cursor': ?cursor,
      'limit': limit.clamp(1, 40),
    });
  }

  @override
  Future<Result<MarketplacePage>> loadMyListings({
    ListingStatus? status,
    String? cursor,
    int limit = 24,
  }) {
    return _pageCall('loadMyMarketplaceListings', <String, Object?>{
      if (status != null) 'status': status.name,
      'cursor': ?cursor,
      'limit': limit.clamp(1, 40),
    });
  }

  @override
  Future<Result<MarketplaceSellerProfile>> loadSeller(String sellerId) async {
    try {
      final FirestoreMap data = await _call(
        'getMarketplaceSeller',
        <String, Object?>{'sellerId': sellerId},
      );
      final FirestoreMap seller = FirestoreParser.map(data, 'seller');
      return Success<MarketplaceSellerProfile>(
        MarketplaceSellerProfile(
          uid: FirestoreParser.string(seller, 'uid'),
          username: FirestoreParser.string(seller, 'username', fallback: ''),
          displayName: FirestoreParser.string(
            seller,
            'displayName',
            fallback: 'Athlete',
          ),
          avatarUrl: FirestoreParser.nullableString(seller, 'avatarUrl'),
          isVerified: FirestoreParser.boolean(
            seller,
            'isVerified',
            fallback: false,
          ),
          verificationType: FirestoreParser.nullableString(
            seller,
            'verificationType',
          ),
          locality: FirestoreParser.nullableString(seller, 'locality'),
          activeListingCount: FirestoreParser.integer(
            seller,
            'activeListingCount',
            fallback: 0,
          ),
          soldListingCount: FirestoreParser.integer(
            seller,
            'soldListingCount',
            fallback: 0,
          ),
          memberSince: FirestoreParser.dateTime(seller, 'memberSince'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<MarketplaceSellerProfile>(
        MarketplaceFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<MarketplaceSellerProfile>(
        MarketplaceFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<bool>> watchFavorite(String listingId) async* {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield const Success<bool>(false);
      return;
    }
    try {
      final DocumentReference<FirestoreMap> favorite = _firestore
          .collection('users')
          .doc(uid)
          .collection('marketplace_favorites')
          .doc(listingId);
      await for (final DocumentSnapshot<FirestoreMap> snapshot
          in favorite.snapshots()) {
        yield Success<bool>(snapshot.exists);
      }
    } on FirebaseException catch (error) {
      yield FailureResult<bool>(MarketplaceFailureMapper.fromFirestore(error));
    } on Object catch (error) {
      yield FailureResult<bool>(MarketplaceFailureMapper.unexpected(error));
    }
  }

  @override
  Stream<Result<Set<String>>> watchFavoriteIds() async* {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield const Success<Set<String>>(<String>{});
      return;
    }
    try {
      final CollectionReference<FirestoreMap> favorites = _firestore
          .collection('users')
          .doc(uid)
          .collection('marketplace_favorites');
      await for (final QuerySnapshot<FirestoreMap> snapshot
          in favorites
              .orderBy('createdAt', descending: true)
              .limit(200)
              .snapshots()) {
        yield Success<Set<String>>(
          snapshot.docs.map((item) => item.id).toSet(),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<Set<String>>(
        MarketplaceFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<Set<String>>(
        MarketplaceFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<String>> createDraft(MarketplaceListingDraft draft) async {
    try {
      final FirestoreMap data = await _call(
        'createMarketplaceListing',
        _draftMap(draft),
      );
      return Success<String>(FirestoreParser.string(data, 'listingId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(
        MarketplaceFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<String>(MarketplaceFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> saveDraft(MarketplaceListingDraft draft) =>
      _voidCall('updateMarketplaceListing', _draftMap(draft));

  @override
  Future<Result<void>> publish(String listingId) => _voidCall(
    'publishMarketplaceListing',
    <String, Object?>{'listingId': listingId},
  );

  @override
  Future<Result<void>> changeStatus({
    required String listingId,
    required MarketplaceListingAction action,
  }) => _voidCall('changeMarketplaceListingStatus', <String, Object?>{
    'listingId': listingId,
    'action': action.name,
  });

  @override
  Future<Result<bool>> toggleFavorite(String listingId) async {
    try {
      final FirestoreMap data = await _call(
        'toggleMarketplaceFavorite',
        <String, Object?>{'listingId': listingId},
      );
      return Success<bool>(
        FirestoreParser.boolean(data, 'isFavorited', fallback: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<bool>(MarketplaceFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<bool>(MarketplaceFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> recordView(String listingId) => _voidCall(
    'recordMarketplaceView',
    <String, Object?>{'listingId': listingId},
  );

  @override
  Future<Result<void>> report({
    required String listingId,
    required MarketplaceReportReason reason,
    String details = '',
  }) => _voidCall('reportMarketplaceListing', <String, Object?>{
    'listingId': listingId,
    'reason': reason.name,
    'details': details,
  });

  @override
  Future<Result<String>> startConversation(String listingId) async {
    try {
      final FirestoreMap data = await _call(
        'startMarketplaceConversation',
        <String, Object?>{'listingId': listingId},
      );
      return Success<String>(FirestoreParser.string(data, 'conversationId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(
        MarketplaceFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<String>(MarketplaceFailureMapper.unexpected(error));
    }
  }

  Future<Result<MarketplacePage>> _pageCall(
    String name,
    Map<String, Object?> request,
  ) async {
    try {
      final FirestoreMap data = await _call(name, request);
      final List<MarketplaceListing> items =
          FirestoreParser.mapList(data, 'items')
              .map((FirestoreMap item) {
                final String id = FirestoreParser.string(item, 'id');
                return MarketplaceListingDto.fromMap(id, item).toDomain();
              })
              .toList(growable: false);
      return Success<MarketplacePage>(
        MarketplacePage(
          items: items,
          hasMore: FirestoreParser.boolean(data, 'hasMore', fallback: false),
          nextCursor: FirestoreParser.nullableString(data, 'nextCursor'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<MarketplacePage>(
        MarketplaceFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<MarketplacePage>(
        MarketplaceFailureMapper.unexpected(error),
      );
    }
  }

  Future<Result<void>> _voidCall(
    String name,
    Map<String, Object?> request,
  ) async {
    try {
      await _call(name, request);
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(MarketplaceFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<void>(MarketplaceFailureMapper.unexpected(error));
    }
  }

  Future<FirestoreMap> _call(String name, Map<String, Object?> request) async {
    final HttpsCallableResult<dynamic> response = await _functions
        .httpsCallable(name)
        .call<dynamic>(request);
    final Object? value = response.data;
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const FormatException('The server returned an invalid response.');
  }

  static Map<String, Object?> _draftMap(MarketplaceListingDraft draft) {
    return <String, Object?>{
      'listingId': draft.id,
      'title': draft.title,
      'description': draft.description,
      'categoryId': draft.categoryId,
      'sportId': draft.sportId,
      'condition': draft.condition.name,
      'price': <String, Object?>{
        'amountMinor': draft.priceAmountMinor,
        'currency': draft.currency,
      },
      'isNegotiable': draft.isNegotiable,
      'deliveryOptions': draft.deliveryOptions
          .map((MarketplaceDeliveryOption item) => item.name)
          .toList(growable: false),
      'media': draft.media
          .map(
            (item) => <String, Object?>{
              'id': item.id,
              'storagePath': item.storagePath,
              'kind': item.kind.name,
              'processingState': item.processingState.name,
              if (item.downloadUrl != null) 'downloadUrl': item.downloadUrl,
              if (item.contentType != null) 'contentType': item.contentType,
              if (item.sizeBytes != null) 'sizeBytes': item.sizeBytes,
            },
          )
          .toList(growable: false),
      if (draft.location != null) ...<String, Object?>{
        'location': <String, double>{
          'latitude': draft.location!.latitude,
          'longitude': draft.location!.longitude,
        },
        'geohash': draft.location!.geohash,
        if (draft.location!.locality != null)
          'locality': draft.location!.locality,
        if (draft.location!.administrativeArea != null)
          'administrativeArea': draft.location!.administrativeArea,
        if (draft.location!.countryCode != null)
          'countryCode': draft.location!.countryCode,
      },
    };
  }
}
