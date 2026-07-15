import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/providers/core_providers.dart';
import '../../core/responsive/app_breakpoints.dart';
import '../../features/messages/application/messaging_providers.dart';
import '../router/app_routes.dart';
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
      ref.listen<AsyncValue<String>>(messagingOpenedConversationProvider, (
        AsyncValue<String>? previous,
        AsyncValue<String> next,
      ) {
        next.whenData(
          (String conversationId) =>
              context.go(AppRoutes.conversation(conversationId)),
        );
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
