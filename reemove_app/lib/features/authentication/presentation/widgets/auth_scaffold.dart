import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../core/responsive/app_breakpoints.dart';
import '../../../../core/widgets/reemove_logo.dart';

class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    required this.child,
    super.key,
    this.heroTitle = 'Move together.\nGrow stronger.',
    this.heroMessage =
        'Connect with players, training partners, teams, events, challenges, and places built around how you move.',
    this.showBackButton = false,
    this.onBack,
  });

  final Widget child;
  final String heroTitle;
  final String heroMessage;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    scheme.surface,
                    scheme.primaryContainer.withValues(alpha: 0.34),
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -160,
            right: -120,
            child: _Orb(
              size: 430,
              color: AppColors.brand.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -210,
            left: -150,
            child: _Orb(
              size: 500,
              color: AppColors.accent.withValues(alpha: 0.11),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= AppBreakpoints.medium;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? AppSpacing.xxl : AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppBreakpoints.maxContentWidth,
                      ),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              if (showBackButton) ...<Widget>[
                                IconButton.filledTonal(
                                  tooltip: 'Back',
                                  onPressed:
                                      onBack ??
                                      () => Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                              ],
                              const ReeMoveLogo(size: 44),
                              const Spacer(),
                              IconButton.filledTonal(
                                tooltip: 'Toggle light or dark appearance',
                                onPressed: () => ref
                                    .read(themeModeProvider.notifier)
                                    .toggle(Theme.of(context).brightness),
                                icon: Icon(
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: wide ? 62 : 34),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: _AuthHero(
                                    title: heroTitle,
                                    message: heroMessage,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xxl),
                                Expanded(child: child),
                              ],
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 540),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _AuthHero(
                                    title: heroTitle,
                                    message: heroMessage,
                                    compact: true,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  child,
                                ],
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.title,
    required this.message,
    this.compact = false,
  });

  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.bolt_rounded, size: 18, color: AppColors.brandDeep),
              SizedBox(width: AppSpacing.xs),
              Text('YOUR SPORT. YOUR PEOPLE.'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: text.displayLarge?.copyWith(fontSize: compact ? 45 : 66),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          message,
          style: text.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: compact ? 16 : 18,
          ),
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _FeaturePill(
                icon: Icons.groups_rounded,
                label: 'Find your people',
              ),
              _FeaturePill(
                icon: Icons.location_on_rounded,
                label: 'Move nearby',
              ),
              _FeaturePill(
                icon: Icons.emoji_events_rounded,
                label: 'Reach new goals',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(label),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: <BoxShadow>[
            BoxShadow(color: color, blurRadius: 90, spreadRadius: 22),
          ],
        ),
      ),
    );
  }
}
