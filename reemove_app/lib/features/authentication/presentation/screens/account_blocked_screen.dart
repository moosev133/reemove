import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../application/authentication_providers.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_scaffold.dart';

class AccountBlockedScreen extends ConsumerWidget {
  const AccountBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? reason = ref.watch(authRoutingStateProvider).value?.reason;
    return AuthScaffold(
      heroTitle: 'Community safety\ncomes first.',
      heroMessage:
          'ReeMove protects athletes, teams, and communities through clear account and moderation controls.',
      child: AuthCard(
        icon: Icons.gpp_maybe_rounded,
        title: 'Account unavailable',
        subtitle: reason ?? 'This account cannot access ReeMove right now.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Contact ReeMove support from the verified email on your account if you believe this is a mistake.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(authActionControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
