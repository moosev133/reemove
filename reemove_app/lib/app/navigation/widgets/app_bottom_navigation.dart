import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../app_destination.dart';
import '../app_navigation_badges.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selectedIndex,
    required this.badges,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final AppNavigationBadges badges;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: AppDestination.values
              .map((AppDestination destination) {
                final bool isCreate = destination == AppDestination.create;
                return NavigationDestination(
                  tooltip: destination.tooltip,
                  icon: _DestinationIcon(
                    destination: destination,
                    count: badges.countFor(destination),
                    selected: false,
                    emphasize: isCreate,
                  ),
                  selectedIcon: _DestinationIcon(
                    destination: destination,
                    count: badges.countFor(destination),
                    selected: true,
                    emphasize: isCreate,
                  ),
                  label: destination.label,
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({
    required this.destination,
    required this.count,
    required this.selected,
    required this.emphasize,
  });

  final AppDestination destination;
  final int count;
  final bool selected;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    Widget icon = Icon(selected ? destination.selectedIcon : destination.icon);
    if (emphasize) {
      icon = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : AppColors.brand.withValues(alpha: 0.18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            selected ? destination.selectedIcon : destination.icon,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    if (count <= 0) {
      return icon;
    }
    return Badge.count(count: count, isLabelVisible: true, child: icon);
  }
}
