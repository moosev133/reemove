import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/app/navigation/app_destination.dart';

void main() {
  test('defines the six mandatory destinations in product order', () {
    expect(AppDestination.values, <AppDestination>[
      AppDestination.home,
      AppDestination.discover,
      AppDestination.sports,
      AppDestination.create,
      AppDestination.messages,
      AppDestination.profile,
    ]);
  });

  test('resolves nested locations to their owning branch', () {
    expect(
      AppDestination.fromLocation('/home/post/post-1'),
      AppDestination.home,
    );
    expect(
      AppDestination.fromLocation('/discover/search?q=run'),
      AppDestination.discover,
    );
    expect(
      AppDestination.fromLocation('/messages/conversation-1'),
      AppDestination.messages,
    );
  });

  test('falls back to home for unknown locations', () {
    expect(AppDestination.fromLocation('/unknown'), AppDestination.home);
  });
}
