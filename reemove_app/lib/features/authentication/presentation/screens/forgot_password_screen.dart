import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../application/authentication_providers.dart';
import '../../domain/value_objects/auth_validators.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool success = await ref
        .read(authActionControllerProvider.notifier)
        .sendPasswordResetEmail(AuthValidators.normalizeEmail(_email.text));
    if (mounted && success) {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> action = ref.watch(authActionControllerProvider);
    final bool loading = action.isLoading;
    return AuthScaffold(
      showBackButton: true,
      onBack: () => context.go(
        AppRoutes.inheritReturnTo(
          GoRouterState.of(context).uri,
          AppRoutes.signIn,
        ),
      ),
      heroTitle: 'Reset. Recover.\nKeep moving.',
      heroMessage:
          'We will send a secure password reset link to your account email.',
      child: AuthCard(
        icon: Icons.lock_reset_rounded,
        title: 'Reset your password',
        subtitle:
            'For privacy, the confirmation looks the same whether or not an account exists.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (action.hasError) ...<Widget>[
                AuthErrorBanner(error: action.error!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_sent) ...<Widget>[
                const AuthSuccessBanner(
                  message:
                      'Check your inbox and follow the password reset instructions.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AuthTextField(
                controller: _email,
                label: 'Email',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.email],
                validator: AuthValidators.email,
                enabled: !loading,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthPrimaryButton(
                label: _sent ? 'Send another link' : 'Send reset link',
                loading: loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: loading
                    ? null
                    : () => context.go(
                        AppRoutes.inheritReturnTo(
                          GoRouterState.of(context).uri,
                          AppRoutes.signIn,
                        ),
                      ),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
