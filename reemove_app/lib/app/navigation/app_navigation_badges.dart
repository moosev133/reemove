import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_destination.dart';

class AppNavigationBadges {
  const AppNavigationBadges({this.activity = 0, this.messages = 0});

  final int activity;
  final int messages;

  int countFor(AppDestination destination) => switch (destination) {
    AppDestination.home => activity,
    AppDestination.messages => messages,
    AppDestination.discover ||
    AppDestination.sports ||
    AppDestination.create ||
    AppDestination.profile => 0,
  };

  AppNavigationBadges copyWith({int? activity, int? messages}) {
    return AppNavigationBadges(
      activity: activity ?? this.activity,
      messages: messages ?? this.messages,
    );
  }
}

final NotifierProvider<AppNavigationBadgeController, AppNavigationBadges>
appNavigationBadgesProvider =
    NotifierProvider<AppNavigationBadgeController, AppNavigationBadges>(
      AppNavigationBadgeController.new,
    );

class AppNavigationBadgeController extends Notifier<AppNavigationBadges> {
  @override
  AppNavigationBadges build() => const AppNavigationBadges();

  void updateActivity(int count) {
    state = state.copyWith(activity: _normalized(count));
  }

  void updateMessages(int count) {
    state = state.copyWith(messages: _normalized(count));
  }

  void clear(AppDestination destination) {
    switch (destination) {
      case AppDestination.home:
        updateActivity(0);
        return;
      case AppDestination.messages:
        updateMessages(0);
        return;
      case AppDestination.discover:
      case AppDestination.sports:
      case AppDestination.create:
      case AppDestination.profile:
        return;
    }
  }

  int _normalized(int value) => value.clamp(0, 999).toInt();
}
