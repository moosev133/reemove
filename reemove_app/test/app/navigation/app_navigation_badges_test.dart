import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/app/navigation/app_destination.dart';
import 'package:reemove/app/navigation/app_navigation_badges.dart';

void main() {
  test('normalizes badge counts and clears supported destinations', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final AppNavigationBadgeController controller = container.read(
      appNavigationBadgesProvider.notifier,
    );

    controller.updateActivity(-10);
    controller.updateMessages(5000);

    expect(container.read(appNavigationBadgesProvider).activity, 0);
    expect(container.read(appNavigationBadgesProvider).messages, 999);

    controller.clear(AppDestination.messages);
    expect(container.read(appNavigationBadgesProvider).messages, 0);
  });
}
