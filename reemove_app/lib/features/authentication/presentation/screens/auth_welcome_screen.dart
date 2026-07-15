import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../application/authentication_providers.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_scaffold.dart';

class AuthWelcomeScreen extends ConsumerWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<void> action = ref.watch(authActionControllerProvider);
    final bool loading = action.isLoading;

    return AuthScaffold(
      child: AuthCard(
        title: 'Welcome to ReeMove',
        subtitle: 'Create your sports identity or continue where you left off.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (action.hasError) ...<Widget>[
              AuthErrorBanner(error: action.error!),
              const SizedBox(height: AppSpacing.md),
            ],
            AuthPrimaryButton(
              label: 'Create an account',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => context.go(
                AppRoutes.inheritReturnTo(
                  GoRouterState.of(context).uri,
                  AppRoutes.signUp,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: loading
                  ? null
                  : () => context.go(
                      AppRoutes.inheritReturnTo(
                        GoRouterState.of(context).uri,
                        AppRoutes.signIn,
                      ),
                    ),
              child: const Text('Sign in with email'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'or continue with',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SocialAuthButton(
              label: 'Google',
              icon: Icons.g_mobiledata_rounded,
              loading: loading,
              onPressed: () => ref
                  .read(authActionControllerProvider.notifier)
                  .signInWithGoogle(),
            ),
            const SizedBox(height: AppSpacing.sm),
            SocialAuthButton(
              label: 'Apple',
              icon: Icons.apple,
              loading: loading,
              onPressed: () => ref
                  .read(authActionControllerProvider.notifier)
                  .signInWithApple(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'By continuing, you agree to use ReeMove respectfully and follow our community and safety standards.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
