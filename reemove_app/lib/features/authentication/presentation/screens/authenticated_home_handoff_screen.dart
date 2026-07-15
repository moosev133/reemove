import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/authentication_providers.dart';

class AuthenticatedHomeHandoffScreen extends ConsumerWidget {
  const AuthenticatedHomeHandoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReeMove'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Account and security',
            onPressed: () => context.go(AppRoutes.accountSecurity),
            icon: const Icon(Icons.manage_accounts_rounded),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: PremiumSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Welcome back, ${profile?.displayName ?? 'athlete'}.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your secure ReeMove account is active. Your personalized sports experience is being prepared.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(authActionControllerProvider.notifier)
                        .signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
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
