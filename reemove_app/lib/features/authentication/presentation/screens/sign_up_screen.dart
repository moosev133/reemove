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
import '../widgets/legal_consent_fields.dart';
import '../widgets/username_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _ageConfirmed = false;
  bool _showConsentError = false;

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final bool valid = _formKey.currentState?.validate() ?? false;
    final bool consentsValid =
        _acceptedTerms && _acceptedPrivacy && _ageConfirmed;
    setState(() => _showConsentError = !consentsValid);
    if (!valid || !consentsValid) {
      return;
    }
    await ref
        .read(authActionControllerProvider.notifier)
        .registerAndProvision(
          email: AuthValidators.normalizeEmail(_email.text),
          password: _password.text,
          displayName: _displayName.text.trim(),
          username: AuthValidators.normalizeUsername(_username.text),
          acceptedTerms: _acceptedTerms,
          acceptedPrivacy: _acceptedPrivacy,
          ageConfirmed: _ageConfirmed,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> action = ref.watch(authActionControllerProvider);
    final bool loading = action.isLoading;
    return AuthScaffold(
      showBackButton: true,
      onBack: () => context.go(AppRoutes.authWelcome),
      heroTitle: 'Build your\nsports identity.',
      heroMessage:
          'Choose a unique username and create one profile for every sport you love.',
      child: AuthCard(
        title: 'Create your account',
        subtitle: 'Your username is how people will find and follow you.',
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
                  controller: _displayName,
                  label: 'Full name',
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.name],
                  validator: AuthValidators.displayName,
                  enabled: !loading,
                ),
                const SizedBox(height: AppSpacing.md),
                UsernameField(controller: _username, enabled: !loading),
                const SizedBox(height: AppSpacing.md),
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
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  validator: AuthValidators.strongPassword,
                  obscureText: true,
                  enabled: !loading,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.md),
                LegalConsentFields(
                  acceptedTerms: _acceptedTerms,
                  acceptedPrivacy: _acceptedPrivacy,
                  ageConfirmed: _ageConfirmed,
                  onTermsChanged: (bool value) =>
                      setState(() => _acceptedTerms = value),
                  onPrivacyChanged: (bool value) =>
                      setState(() => _acceptedPrivacy = value),
                  onAgeChanged: (bool value) =>
                      setState(() => _ageConfirmed = value),
                ),
                if (_showConsentError) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Confirm all three items to create your account.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AuthPrimaryButton(
                  label: 'Create account',
                  icon: Icons.arrow_forward_rounded,
                  loading: loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => context.go(AppRoutes.signIn),
                  child: const Text('I already have an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
