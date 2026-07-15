import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/responsive/app_breakpoints.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../../core/widgets/reemove_logo.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    final FirebaseBootstrapReport firebase = ref.watch(
      firebaseBootstrapReportProvider,
    );
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
                    scheme.primaryContainer.withValues(alpha: 0.32),
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -100,
            child: _GlowOrb(
              size: 340,
              color: AppColors.brand.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _GlowOrb(
              size: 380,
              color: AppColors.accent.withValues(alpha: 0.12),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const ReeMoveLogo(size: 46),
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
                          SizedBox(height: wide ? 88 : 56),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: _HeroCopy(environment.displayName),
                                ),
                                const SizedBox(width: AppSpacing.xxl),
                                Expanded(
                                  child: _FoundationCard(firebase: firebase),
                                ),
                              ],
                            )
                          else ...<Widget>[
                            _HeroCopy(environment.displayName),
                            const SizedBox(height: AppSpacing.xl),
                            _FoundationCard(firebase: firebase),
                          ],
                          const SizedBox(height: AppSpacing.xxl),
                          const _PrinciplesStrip(),
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

class _HeroCopy extends StatelessWidget {
  const _HeroCopy(this.environmentName);

  final String environmentName;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppStatusChip(
          label: '$environmentName foundation',
          icon: Icons.bolt_rounded,
          color: AppColors.brandDeep,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Move together.\nGrow stronger.',
          style: text.displayLarge?.copyWith(fontSize: 64),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'ReeMove is being built as one premium sports ecosystem for '
          'social content, nearby activity, teams, events, challenges, '
          'marketplace tools, and AI-powered coaching.',
          style: text.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _FoundationCard extends StatelessWidget {
  const _FoundationCard({required this.firebase});

  final FirebaseBootstrapReport firebase;

  @override
  Widget build(BuildContext context) {
    final bool ready = firebase.isReady;
    final Color statusColor = ready ? AppColors.success : AppColors.warning;

    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  ready
                      ? Icons.verified_rounded
                      : Icons.settings_suggest_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Architecture initialized',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ready
                          ? 'Firebase connection is ready.'
                          : 'Add the project-specific FlutterFire files.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FoundationRow(
            icon: Icons.account_tree_rounded,
            title: 'Feature-first Clean Architecture',
            subtitle: 'Independent modules with provider-neutral domains.',
          ),
          const _FoundationRow(
            icon: Icons.palette_rounded,
            title: 'Premium adaptive design system',
            subtitle: 'Material 3, light/dark modes, responsive foundations.',
          ),
          const _FoundationRow(
            icon: Icons.security_rounded,
            title: 'Security from day one',
            subtitle: 'Deny-by-default rules and optional App Check.',
          ),
          const _FoundationRow(
            icon: Icons.route_rounded,
            title: 'Scalable navigation and deep links',
            subtitle: 'GoRouter composition ready for nested feature routes.',
          ),
          if (!ready) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'The app remains usable in development so the UI foundation '
              'can be reviewed before owner-specific Firebase credentials '
              'are generated.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FoundationRow extends StatelessWidget {
  const _FoundationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinciplesStrip extends StatelessWidget {
  const _PrinciplesStrip();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: const <Widget>[
        _Principle(label: 'Mobile-first', icon: Icons.phone_iphone_rounded),
        _Principle(label: 'Fast', icon: Icons.speed_rounded),
        _Principle(label: 'Modular', icon: Icons.widgets_rounded),
        _Principle(label: 'AI-ready', icon: Icons.auto_awesome_rounded),
        _Principle(label: 'Investor-grade', icon: Icons.trending_up_rounded),
      ],
    );
  }
}

class _Principle extends StatelessWidget {
  const _Principle({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 17),
            const SizedBox(width: 7),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

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
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
