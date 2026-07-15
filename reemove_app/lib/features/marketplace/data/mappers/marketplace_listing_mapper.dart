import '../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../dto/marketplace_listing_dto.dart';

extension MarketplaceListingDtoMapper on MarketplaceListingDto {
  MarketplaceListing toDomain() => MarketplaceListing(
    id: id,
    sellerId: sellerId,
    seller: SellerSnapshot(
      uid: seller.uid,
      username: seller.username,
      displayName: seller.displayName,
      avatarUrl: seller.avatarUrl,
      isVerified: seller.isVerified,
      verificationType: seller.verificationType,
    ),
    title: title,
    description: description,
    categoryId: categoryId,
    sportId: sportId,
    condition: ListingCondition.values.byName(condition),
    price: price.toDomain(),
    media: media.map((item) => item.toDomain()).toList(growable: false),
    location: location.toDomain(),
    deliveryOptions: deliveryOptions
        .map(MarketplaceDeliveryOption.values.byName)
        .toList(growable: false),
    status: ListingStatus.values.byName(status),
    favoriteCount: favoriteCount,
    viewCount: viewCount,
    conversationCount: conversationCount,
    isNegotiable: isNegotiable,
    isFavorited: isFavorited,
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    audit: audit.toDomain(),
    distanceKm: distanceKm,
    publishedAt: publishedAt,
    expiresAt: expiresAt,
    reservedAt: reservedAt,
    soldAt: soldAt,
    rejectionReason: rejectionReason,
  );
}
