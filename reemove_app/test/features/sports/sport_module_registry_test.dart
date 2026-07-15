import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/sports/shared/domain/services/sport_module_registry.dart';

void main() {
  group('SportModuleRegistry', () {
    test('fully implements the three launch sports', () {
      expect(
        SportModuleRegistry.implemented.map(
          (SportModuleConfig item) => item.id,
        ),
        <String>['football', 'gym', 'running'],
      );
      expect(
        SportModuleRegistry.running.features,
        contains(SportHubFeature.routes),
      );
      expect(
        SportModuleRegistry.gym.features,
        contains(SportHubFeature.pricing),
      );
      expect(SportModuleRegistry.football.communityLabel, 'Teams & groups');
    });

    test('creates a reusable default module for future sports', () {
      final SportModuleConfig cycling = SportModuleRegistry.resolve(
        'road_cycling',
      );

      expect(cycling.id, 'road_cycling');
      expect(cycling.title, 'Road Cycling');
      expect(cycling.features, contains(SportHubFeature.communities));
      expect(cycling.features, contains(SportHubFeature.trainers));
    });
  });
}
