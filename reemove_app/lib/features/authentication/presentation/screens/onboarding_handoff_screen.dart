import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../../core/widgets/reemove_logo.dart';
import '../../application/authentication_providers.dart';

class OnboardingHandoffScreen extends ConsumerWidget {
  const OnboardingHandoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: <Widget>[
                  const ReeMoveLogo(size: 58),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Your account is ready.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 52),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Next, ReeMove will personalize your experience around your sports, level, location, and goals.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PremiumSurface(
                    child: Column(
                      children: <Widget>[
                        const _SetupItem(
                          icon: Icons.sports_soccer_rounded,
                          title: 'Choose your sports',
                          text: 'Football, gym, running, and future sports.',
                        ),
                        const Divider(height: AppSpacing.xl),
                        const _SetupItem(
                          icon: Icons.trending_up_rounded,
                          title: 'Set your level and goals',
                          text: 'Make recommendations relevant from day one.',
                        ),
                        const Divider(height: AppSpacing.xl),
                        const _SetupItem(
                          icon: Icons.location_on_rounded,
                          title: 'Control nearby discovery',
                          text:
                              'Location permissions remain clear and optional.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue to sports setup'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sports setup is temporarily unavailable in this build.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton.icon(
                    onPressed: () => context.go(AppRoutes.accountSecurity),
                    icon: const Icon(Icons.manage_accounts_rounded),
                    label: const Text('Account and security'),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(authActionControllerProvider.notifier)
                        .signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupItem extends StatelessWidget {
  const _SetupItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(child: Icon(icon)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
