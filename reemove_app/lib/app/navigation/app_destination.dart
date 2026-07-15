import 'package:flutter/material.dart';

import '../../core/testing/test_keys.dart';
import '../router/app_routes.dart';

enum AppDestination {
  home,
  discover,
  sports,
  create,
  messages,
  profile;

  Key get testKey => switch (this) {
    AppDestination.home => TestKeys.navHome,
    AppDestination.discover => TestKeys.navDiscover,
    AppDestination.sports => TestKeys.navSports,
    AppDestination.create => TestKeys.navCreate,
    AppDestination.messages => TestKeys.navMessages,
    AppDestination.profile => TestKeys.navProfile,
  };

  int get branchIndex => index;

  String get label => switch (this) {
    AppDestination.home => 'Home',
    AppDestination.discover => 'Discover',
    AppDestination.sports => 'Sports',
    AppDestination.create => 'Create',
    AppDestination.messages => 'Messages',
    AppDestination.profile => 'Profile',
  };

  String get tooltip => switch (this) {
    AppDestination.home => 'Open your home feed',
    AppDestination.discover => 'Discover people, places, and events',
    AppDestination.sports => 'Open your sports hubs',
    AppDestination.create => 'Create something new',
    AppDestination.messages => 'Open your conversations',
    AppDestination.profile => 'Open your profile',
  };

  String get location => switch (this) {
    AppDestination.home => AppRoutes.home,
    AppDestination.discover => AppRoutes.discover,
    AppDestination.sports => AppRoutes.sports,
    AppDestination.create => AppRoutes.create,
    AppDestination.messages => AppRoutes.messages,
    AppDestination.profile => AppRoutes.profile,
  };

  IconData get icon => switch (this) {
    AppDestination.home => Icons.home_outlined,
    AppDestination.discover => Icons.explore_outlined,
    AppDestination.sports => Icons.sports_soccer_outlined,
    AppDestination.create => Icons.add_circle_outline_rounded,
    AppDestination.messages => Icons.chat_bubble_outline_rounded,
    AppDestination.profile => Icons.person_outline_rounded,
  };

  IconData get selectedIcon => switch (this) {
    AppDestination.home => Icons.home_rounded,
    AppDestination.discover => Icons.explore_rounded,
    AppDestination.sports => Icons.sports_soccer_rounded,
    AppDestination.create => Icons.add_circle_rounded,
    AppDestination.messages => Icons.chat_bubble_rounded,
    AppDestination.profile => Icons.person_rounded,
  };

  static AppDestination fromLocation(String location) {
    final String normalized = Uri.tryParse(location)?.path ?? location;
    return AppDestination.values.firstWhere(
      (AppDestination destination) =>
          normalized == destination.location ||
          normalized.startsWith('${destination.location}/'),
      orElse: () => AppDestination.home,
    );
  }
}
