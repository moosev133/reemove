import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../application/authentication_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_scaffold.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _sent = false;

  Future<void> _send() async {
    final bool success = await ref
        .read(authActionControllerProvider.notifier)
        .sendEmailVerification();
    if (mounted && success) {
      setState(() => _sent = true);
    }
  }

  Future<void> _refresh() async {
    await ref.read(authActionControllerProvider.notifier).reloadCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> action = ref.watch(authActionControllerProvider);
    final AuthUser? user = ref.watch(currentAuthUserProvider).value;
    final bool loading = action.isLoading;
    return AuthScaffold(
      heroTitle: 'One quick check.\nThen you are in.',
      heroMessage:
          'Email verification protects your identity and helps keep the ReeMove community trustworthy.',
      child: AuthCard(
        icon: Icons.mark_email_read_outlined,
        title: 'Verify your email',
        subtitle: user?.email == null
            ? 'Open the verification message sent to your email.'
            : 'We sent a verification link to ${user!.email}.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (action.hasError) ...<Widget>[
              AuthErrorBanner(error: action.error!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_sent) ...<Widget>[
              const AuthSuccessBanner(
                message: 'A new verification email has been sent.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              'After opening the link, return here and tap “I verified my email.”',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthPrimaryButton(
              label: 'I verified my email',
              icon: Icons.refresh_rounded,
              loading: loading,
              onPressed: _refresh,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: loading ? null : _send,
              child: const Text('Resend verification email'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: loading
                  ? null
                  : () => ref
                        .read(authActionControllerProvider.notifier)
                        .signOut(),
              child: const Text('Use a different account'),
            ),
          ],
        ),
      ),
    );
  }
}
