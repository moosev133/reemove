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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(authActionControllerProvider.notifier)
        .signInWithEmail(
          email: AuthValidators.normalizeEmail(_email.text),
          password: _password.text,
        );
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
          AppRoutes.authWelcome,
        ),
      ),
      heroTitle: 'Your next move\nstarts here.',
      heroMessage:
          'Return to your training partners, events, challenges, and sports communities.',
      child: AuthCard(
        title: 'Sign in',
        subtitle: 'Use your ReeMove email and password.',
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (action.hasError) ...<Widget>[
                  AuthErrorBanner(error: action.error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.email],
                  validator: AuthValidators.email,
                  enabled: !loading,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  controller: _password,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.password],
                  validator: AuthValidators.password,
                  obscureText: true,
                  enabled: !loading,
                  onFieldSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading
                        ? null
                        : () => context.go(
                            AppRoutes.inheritReturnTo(
                              GoRouterState.of(context).uri,
                              AppRoutes.forgotPassword,
                            ),
                          ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                AuthPrimaryButton(
                  label: 'Sign in',
                  loading: loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text('New to ReeMove?'),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => context.go(
                              AppRoutes.inheritReturnTo(
                                GoRouterState.of(context).uri,
                                AppRoutes.signUp,
                              ),
                            ),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
