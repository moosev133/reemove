import '../../../../core/domain/entities/entity_audit.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/domain/value_objects/media_asset.dart';
import '../../../../core/domain/value_objects/money.dart';

enum ListingCondition { newItem, likeNew, good, fair, poor }

enum ListingStatus {
  draft,
  pendingReview,
  active,
  paused,
  reserved,
  sold,
  expired,
  removed,
  rejected,
}

enum MarketplaceSort { newest, priceLowToHigh, priceHighToLow, nearest }

enum MarketplaceDeliveryOption { pickup, meetup, shipping }

class SellerSnapshot {
  const SellerSnapshot({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.isVerified,
    this.avatarUrl,
    this.verificationType,
  });

  final String uid;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final String? verificationType;
}

class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.sellerId,
    required this.seller,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.sportId,
    required this.condition,
    required this.price,
    required this.media,
    required this.location,
    required this.deliveryOptions,
    required this.status,
    required this.favoriteCount,
    required this.viewCount,
    required this.conversationCount,
    required this.isNegotiable,
    required this.isFavorited,
    required this.moderationState,
    required this.audit,
    this.distanceKm,
    this.publishedAt,
    this.expiresAt,
    this.reservedAt,
    this.soldAt,
    this.rejectionReason,
  });

  final String id;
  final String sellerId;
  final SellerSnapshot seller;
  final String title;
  final String description;
  final String categoryId;
  final String sportId;
  final ListingCondition condition;
  final Money price;
  final List<MediaAsset> media;
  final GeoLocation location;
  final List<MarketplaceDeliveryOption> deliveryOptions;
  final ListingStatus status;
  final int favoriteCount;
  final int viewCount;
  final int conversationCount;
  final bool isNegotiable;
  final bool isFavorited;
  final ModerationState moderationState;
  final EntityAudit audit;
  final double? distanceKm;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? reservedAt;
  final DateTime? soldAt;
  final String? rejectionReason;

  bool get canEditBySeller => <ListingStatus>{
    ListingStatus.draft,
    ListingStatus.paused,
    ListingStatus.expired,
    ListingStatus.rejected,
  }.contains(status);

  bool get canReceiveMessages =>
      status == ListingStatus.active || status == ListingStatus.reserved;

  MarketplaceListing copyWith({
    bool? isFavorited,
    int? favoriteCount,
    int? viewCount,
    ListingStatus? status,
    double? distanceKm,
  }) {
    return MarketplaceListing(
      id: id,
      sellerId: sellerId,
      seller: seller,
      title: title,
      description: description,
      categoryId: categoryId,
      sportId: sportId,
      condition: condition,
      price: price,
      media: media,
      location: location,
      deliveryOptions: deliveryOptions,
      status: status ?? this.status,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      viewCount: viewCount ?? this.viewCount,
      conversationCount: conversationCount,
      isNegotiable: isNegotiable,
      isFavorited: isFavorited ?? this.isFavorited,
      moderationState: moderationState,
      audit: audit,
      distanceKm: distanceKm ?? this.distanceKm,
      publishedAt: publishedAt,
      expiresAt: expiresAt,
      reservedAt: reservedAt,
      soldAt: soldAt,
      rejectionReason: rejectionReason,
    );
  }
}

class MarketplacePage {
  const MarketplacePage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<MarketplaceListing> items;
  final bool hasMore;
  final String? nextCursor;
}

class MarketplaceSearchFilters {
  const MarketplaceSearchFilters({
    this.query = '',
    this.sportId,
    this.categoryId,
    this.condition,
    this.minimumPriceMinor,
    this.maximumPriceMinor,
    this.deliveryOptions = const <MarketplaceDeliveryOption>{},
    this.sort = MarketplaceSort.newest,
    this.latitude,
    this.longitude,
    this.radiusKm = 50,
  });

  final String query;
  final String? sportId;
  final String? categoryId;
  final ListingCondition? condition;
  final int? minimumPriceMinor;
  final int? maximumPriceMinor;
  final Set<MarketplaceDeliveryOption> deliveryOptions;
  final MarketplaceSort sort;
  final double? latitude;
  final double? longitude;
  final double radiusKm;

  bool get usesLocation => latitude != null && longitude != null;

  MarketplaceSearchFilters copyWith({
    String? query,
    String? sportId,
    bool clearSport = false,
    String? categoryId,
    bool clearCategory = false,
    ListingCondition? condition,
    bool clearCondition = false,
    int? minimumPriceMinor,
    bool clearMinimumPrice = false,
    int? maximumPriceMinor,
    bool clearMaximumPrice = false,
    Set<MarketplaceDeliveryOption>? deliveryOptions,
    MarketplaceSort? sort,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) {
    return MarketplaceSearchFilters(
      query: query ?? this.query,
      sportId: clearSport ? null : sportId ?? this.sportId,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      condition: clearCondition ? null : condition ?? this.condition,
      minimumPriceMinor: clearMinimumPrice
          ? null
          : minimumPriceMinor ?? this.minimumPriceMinor,
      maximumPriceMinor: clearMaximumPrice
          ? null
          : maximumPriceMinor ?? this.maximumPriceMinor,
      deliveryOptions: deliveryOptions ?? this.deliveryOptions,
      sort: sort ?? this.sort,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }
}
