import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../application/authentication_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/value_objects/auth_validators.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/legal_consent_fields.dart';
import '../widgets/username_field.dart';

class UsernameSetupScreen extends ConsumerStatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  ConsumerState<UsernameSetupScreen> createState() =>
      _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends ConsumerState<UsernameSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _username = TextEditingController();
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _ageConfirmed = false;
  bool _initialized = false;
  bool _showConsentError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final AuthUser? user = ref.read(currentAuthUserProvider).value;
    _displayName.text = user?.displayName?.trim() ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
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
        .provisionSocialAccount(
          username: AuthValidators.normalizeUsername(_username.text),
          displayName: _displayName.text.trim(),
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
      heroTitle: 'Claim your name.\nJoin the movement.',
      heroMessage:
          'Your Google or Apple account is connected. Now choose how the ReeMove community will know you.',
      child: AuthCard(
        title: 'Finish account setup',
        subtitle: 'Choose a unique username before personalizing your sports.',
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
                label: 'Display name',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: AuthValidators.displayName,
                enabled: !loading,
              ),
              const SizedBox(height: AppSpacing.md),
              UsernameField(controller: _username, enabled: !loading),
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
                  'Confirm all three items to finish account setup.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AuthPrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                loading: loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: loading
                    ? null
                    : () => ref
                          .read(authActionControllerProvider.notifier)
                          .signOut(),
                child: const Text('Cancel and sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
