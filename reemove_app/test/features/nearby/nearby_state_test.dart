import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/domain/value_objects/geo_location.dart';
import 'package:reemove/features/nearby/domain/entities/nearby_entity.dart';
import 'package:reemove/features/nearby/domain/entities/nearby_search.dart';

void main() {
  test('nearby state defaults to every launch entity type', () {
    final NearbyDiscoveryState state = NearbyDiscoveryState.initial();

    expect(state.radiusKm, 25);
    expect(state.types, NearbyEntityType.values.toSet());
    expect(state.viewMode, NearbyViewMode.map);
    expect(state.selectedEntity, isNull);
  });

  test('copyWith can select and clear a synchronized map/list item', () {
    const NearbyEntity item = NearbyEntity(
      id: 'place_1',
      sourceId: '1',
      type: NearbyEntityType.place,
      title: 'Gym',
      subtitle: 'Haifa',
      location: GeoLocation(latitude: 32.8, longitude: 35, geohash: 'svbc'),
      distanceKm: 1.2,
      distanceLabel: '1.2 km away',
      sportIds: <String>['gym'],
      isVerified: true,
      isApproximate: false,
    );
    final NearbyDiscoveryState selected = NearbyDiscoveryState.initial()
        .copyWith(items: const <NearbyEntity>[item], selectedId: item.id);

    expect(selected.selectedEntity, same(item));
    expect(selected.copyWith(clearSelection: true).selectedEntity, isNull);
  });
}
