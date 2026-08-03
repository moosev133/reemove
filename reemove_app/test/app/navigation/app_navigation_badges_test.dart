import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/app/navigation/app_destination.dart';
import 'package:reemove/app/navigation/app_navigation_badges.dart';

void main() {
  test('activity unread never attaches to Home destination', () {
    const AppNavigationBadges badges = AppNavigationBadges(
      activity: 4,
      messages: 2,
    );
    expect(badges.countFor(AppDestination.home), 0);
    expect(badges.countFor(AppDestination.messages), 2);
    expect(badges.activity, 4);
  });
}
