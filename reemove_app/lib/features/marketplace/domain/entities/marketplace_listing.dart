import '../../../../core/domain/entities/entity_audit.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/domain/value_objects/media_asset.dart';
import '../../../../core/domain/value_objects/money.dart';

enum ListingCondition { newItem, likeNew, good, fair }

enum ListingStatus { draft, active, reserved, sold, removed }

class SellerSnapshot {
  const SellerSnapshot({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.isVerified,
    this.avatarUrl,
  });

  final String uid;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
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
    required this.moderationState,
    required this.audit,
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
  final List<String> deliveryOptions;
  final ListingStatus status;
  final int favoriteCount;
  final int viewCount;
  final ModerationState moderationState;
  final EntityAudit audit;
}
