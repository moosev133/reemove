import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/reemove_logo.dart';
import '../../theme/app_spacing.dart';
import '../../theme/theme_mode_controller.dart';
import '../app_destination.dart';
import '../app_navigation_badges.dart';

class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({
    required this.selectedIndex,
    required this.badges,
    required this.extended,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final AppNavigationBadges badges;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: extended ? 248 : 88,
      child: NavigationRail(
        extended: extended,
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        groupAlignment: -0.72,
        scrollable: true,
        trailingAtBottom: true,
        minExtendedWidth: 248,
        labelType: extended
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.all,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xl,
          ),
          child: extended
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: ReeMoveLogo(size: 40),
                )
              : const ReeMoveLogo(size: 40, showWordmark: false),
        ),
        trailing: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: _ThemeModeButton(extended: extended),
        ),
        destinations: AppDestination.values
            .map((AppDestination destination) {
              final int count = badges.countFor(destination);
              return NavigationRailDestination(
                icon: _RailIcon(icon: destination.icon, count: count),
                selectedIcon: _RailIcon(
                  icon: destination.selectedIcon,
                  count: count,
                ),
                label: Text(destination.label),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final Widget child = Icon(icon);
    if (count <= 0) {
      return child;
    }
    return Badge.count(count: count, child: child);
  }
}

class _ThemeModeButton extends ConsumerWidget {
  const _ThemeModeButton({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    if (!extended) {
      return IconButton(
        tooltip: isDark ? 'Use light theme' : 'Use dark theme',
        onPressed: () =>
            ref.read(themeModeProvider.notifier).toggle(brightness),
        icon: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: OutlinedButton.icon(
        onPressed: () =>
            ref.read(themeModeProvider.notifier).toggle(brightness),
        icon: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        ),
        label: Text(isDark ? 'Light mode' : 'Dark mode'),
      ),
    );
  }
}
