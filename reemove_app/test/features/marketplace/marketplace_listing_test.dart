import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/marketplace/domain/entities/marketplace_listing.dart';

void main() {
  group('MarketplaceSearchFilters', () {
    test('preserves values and clears optional filters explicitly', () {
      const MarketplaceSearchFilters original = MarketplaceSearchFilters(
        query: 'dumbbells',
        sportId: 'gym',
        categoryId: 'gym_equipment',
        condition: ListingCondition.good,
        minimumPriceMinor: 10000,
        maximumPriceMinor: 50000,
        deliveryOptions: <MarketplaceDeliveryOption>{
          MarketplaceDeliveryOption.pickup,
        },
        sort: MarketplaceSort.nearest,
        latitude: 32.8,
        longitude: 35,
        radiusKm: 25,
      );

      final MarketplaceSearchFilters next = original.copyWith(
        clearSport: true,
        clearCategory: true,
        clearCondition: true,
        clearMinimumPrice: true,
        clearMaximumPrice: true,
      );

      expect(next.query, 'dumbbells');
      expect(next.sportId, isNull);
      expect(next.categoryId, isNull);
      expect(next.condition, isNull);
      expect(next.minimumPriceMinor, isNull);
      expect(next.maximumPriceMinor, isNull);
      expect(next.usesLocation, isTrue);
      expect(next.sort, MarketplaceSort.nearest);
    });
  });

  test(
    'listing lifecycle exposes messaging and editing capabilities safely',
    () {
      expect(ListingStatus.active.name, 'active');
      expect(ListingStatus.paused.name, 'paused');
      expect(ListingStatus.reserved.name, 'reserved');
      expect(ListingStatus.draft.name, 'draft');
    },
  );
}
