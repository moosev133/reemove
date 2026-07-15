import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/domain/value_objects/media_asset.dart';
import 'marketplace_listing.dart';

class MarketplaceListingDraft {
  const MarketplaceListingDraft({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.sportId,
    required this.condition,
    required this.priceAmountMinor,
    required this.currency,
    required this.isNegotiable,
    required this.deliveryOptions,
    required this.media,
    this.location,
  });

  factory MarketplaceListingDraft.empty(String id) => MarketplaceListingDraft(
    id: id,
    title: '',
    description: '',
    categoryId: '',
    sportId: 'football',
    condition: ListingCondition.good,
    priceAmountMinor: 0,
    currency: 'ILS',
    isNegotiable: false,
    deliveryOptions: const <MarketplaceDeliveryOption>{
      MarketplaceDeliveryOption.meetup,
    },
    media: const <MediaAsset>[],
  );

  final String id;
  final String title;
  final String description;
  final String categoryId;
  final String sportId;
  final ListingCondition condition;
  final int priceAmountMinor;
  final String currency;
  final bool isNegotiable;
  final Set<MarketplaceDeliveryOption> deliveryOptions;
  final List<MediaAsset> media;
  final GeoLocation? location;

  MarketplaceListingDraft copyWith({
    String? title,
    String? description,
    String? categoryId,
    String? sportId,
    ListingCondition? condition,
    int? priceAmountMinor,
    String? currency,
    bool? isNegotiable,
    Set<MarketplaceDeliveryOption>? deliveryOptions,
    List<MediaAsset>? media,
    GeoLocation? location,
  }) {
    return MarketplaceListingDraft(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      sportId: sportId ?? this.sportId,
      condition: condition ?? this.condition,
      priceAmountMinor: priceAmountMinor ?? this.priceAmountMinor,
      currency: currency ?? this.currency,
      isNegotiable: isNegotiable ?? this.isNegotiable,
      deliveryOptions: deliveryOptions ?? this.deliveryOptions,
      media: media ?? this.media,
      location: location ?? this.location,
    );
  }
}

enum MarketplaceReportReason {
  prohibitedItem,
  scam,
  counterfeit,
  misleading,
  harassment,
  duplicate,
  other,
}

enum MarketplaceListingAction { activate, pause, reserve, sold, remove }
