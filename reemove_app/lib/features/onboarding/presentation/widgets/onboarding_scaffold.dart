import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../core/responsive/app_breakpoints.dart';
import '../../../../core/widgets/reemove_logo.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../onboarding_catalog.dart';

class OnboardingScaffold extends ConsumerWidget {
  const OnboardingScaffold({
    required this.step,
    required this.content,
    required this.navigation,
    super.key,
  });

  final OnboardingStep step;
  final Widget content;
  final Widget navigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int index = OnboardingStep.values.indexOf(step);
    final double progress = (index + 1) / OnboardingStep.values.length;

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
                    scheme.primaryContainer.withValues(alpha: 0.27),
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -140,
            top: -170,
            child: _GlowOrb(
              size: 430,
              color: AppColors.brand.withValues(alpha: 0.17),
            ),
          ),
          Positioned(
            left: -180,
            bottom: -220,
            child: _GlowOrb(
              size: 520,
              color: AppColors.accent.withValues(alpha: 0.09),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= AppBreakpoints.medium;
                return Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? AppSpacing.xxl : AppSpacing.lg,
                        AppSpacing.md,
                        wide ? AppSpacing.xxl : AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: <Widget>[
                          const ReeMoveLogo(size: 40),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip: 'Account and security',
                            onPressed: () =>
                                context.push(AppRoutes.accountSecurity),
                            icon: const Icon(Icons.person_outline_rounded),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          IconButton.filledTonal(
                            tooltip: 'Toggle appearance',
                            onPressed: () => ref
                                .read(themeModeProvider.notifier)
                                .toggle(Theme.of(context).brightness),
                            icon: Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? AppSpacing.xxl : AppSpacing.lg,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppBreakpoints.maxContentWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              wide ? AppSpacing.xxl : AppSpacing.lg,
                              AppSpacing.lg,
                              wide ? AppSpacing.xxl : AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            child: wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      Expanded(
                                        flex: 4,
                                        child: _StepHero(
                                          step: step,
                                          stepNumber: index + 1,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xl),
                                      Expanded(
                                        flex: 6,
                                        child: _ContentCard(
                                          content: content,
                                          navigation: navigation,
                                        ),
                                      ),
                                    ],
                                  )
                                : _ContentCard(
                                    content: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        _CompactHeader(
                                          step: step,
                                          stepNumber: index + 1,
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        content,
                                      ],
                                    ),
                                    navigation: navigation,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content, required this.navigation});

  final Widget content;
  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: content,
            ),
          ),
          Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: navigation,
          ),
        ],
      ),
    );
  }
}

class _StepHero extends StatelessWidget {
  const _StepHero({required this.step, required this.stepNumber});

  final OnboardingStep step;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _StepBadge(stepNumber: stepNumber),
          const SizedBox(height: AppSpacing.lg),
          Text(
            OnboardingCatalog.stepTitle(step),
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(fontSize: 58),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            OnboardingCatalog.stepSubtitle(step),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _PrivacyPill(),
        ],
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.step, required this.stepNumber});

  final OnboardingStep step;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _StepBadge(stepNumber: stepNumber),
        const SizedBox(height: AppSpacing.md),
        Text(
          OnboardingCatalog.stepTitle(step),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          OnboardingCatalog.stepSubtitle(step),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.stepNumber});

  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'STEP $stepNumber OF ${OnboardingStep.values.length}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.brandDeep,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _PrivacyPill extends StatelessWidget {
  const _PrivacyPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.shield_outlined, size: 20),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text('Private by design. Change preferences anytime.'),
          ),
        ],
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
