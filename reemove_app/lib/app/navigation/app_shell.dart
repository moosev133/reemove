import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/providers/core_providers.dart';
import '../../core/responsive/app_breakpoints.dart';
import '../../features/messages/application/messaging_providers.dart';
import '../../features/notifications/application/notification_providers.dart';
import 'app_navigation_badges.dart';
import 'widgets/app_bottom_navigation.dart';
import 'widgets/app_navigation_rail.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FirebaseBootstrapReport report = ref.watch(
      firebaseBootstrapReportProvider,
    );
    if (report.isReady) {
      ref.watch(messagingDeviceRegistrationProvider);
      ref.listen<AsyncValue<int>>(messagingUnreadCountProvider, (
        AsyncValue<int>? previous,
        AsyncValue<int> next,
      ) {
        next.whenData(
          (int count) => ref
              .read(appNavigationBadgesProvider.notifier)
              .updateMessages(count),
        );
      });
      ref.listen<AsyncValue<int>>(notificationUnreadCountProvider, (
        AsyncValue<int>? previous,
        AsyncValue<int> next,
      ) {
        next.whenData(
          (int count) => ref
              .read(appNavigationBadgesProvider.notifier)
              .updateActivity(count),
        );
      });
      // Unified FCM open routing (includes message deep links via data.route).
      ref.listen<AsyncValue<String>>(notificationOpenedRouteProvider, (
        AsyncValue<String>? previous,
        AsyncValue<String> next,
      ) {
        next.whenData(context.go);
      });
      ref.listen<AsyncValue<RemoteMessage>>(foregroundNotificationProvider, (
        AsyncValue<RemoteMessage>? previous,
        AsyncValue<RemoteMessage> next,
      ) {
        next.whenData((RemoteMessage message) {
          final String title =
              message.notification?.title ?? 'New ReeMove update';
          final String body =
              message.notification?.body ?? 'Open Activity to view it.';
          final String? route = notificationRoute(message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title\n$body'),
              action: route == null
                  ? null
                  : SnackBarAction(
                      label: 'Open',
                      onPressed: () => context.go(route),
                    ),
            ),
          );
        });
      });
    }

    final AppNavigationBadges badges = ref.watch(appNavigationBadgesProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < AppBreakpoints.compact) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: AppBottomNavigation(
              selectedIndex: navigationShell.currentIndex,
              badges: badges,
              onSelected: _selectBranch,
            ),
          );
        }

        final bool extended = constraints.maxWidth >= AppBreakpoints.expanded;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: <Widget>[
                AppNavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  badges: badges,
                  extended: extended,
                  onSelected: _selectBranch,
                ),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
