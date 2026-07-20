import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/authentication_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/value_objects/auth_validators.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/logout_action.dart';

class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthUser? user = ref.watch(currentAuthUserProvider).value;
    final AsyncValue<void> action = ref.watch(authActionControllerProvider);
    final bool loading = action.isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.startup);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Account and security'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (action.hasError) ...<Widget>[
                  AuthErrorBanner(error: action.error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                _IdentityCard(user: user, loading: loading),
                const SizedBox(height: AppSpacing.lg),
                if (user != null) ...<Widget>[
                  _SignInMethodsCard(user: user, loading: loading),
                  const SizedBox(height: AppSpacing.lg),
                  _SessionsCard(user: user, loading: loading),
                  const SizedBox(height: AppSpacing.lg),
                  _DeleteAccountCard(user: user, loading: loading),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.user, required this.loading});

  final AuthUser? user;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundImage: user?.photoUrl == null
                    ? null
                    : NetworkImage(user!.photoUrl!),
                child: user?.photoUrl == null
                    ? const Icon(Icons.person_rounded)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user?.displayName ?? 'ReeMove account',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      user?.email ?? 'No account email available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                user?.emailVerified == true
                    ? Icons.verified_rounded
                    : Icons.mark_email_unread_outlined,
                color: user?.emailVerified == true
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: loading
                ? null
                : () => performLogout(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _SignInMethodsCard extends ConsumerWidget {
  const _SignInMethodsCard({required this.user, required this.loading});

  final AuthUser user;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AuthProviderType> connected = user.providers
        .where((AuthProviderType value) => value != AuthProviderType.unknown)
        .toList(growable: false);
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sign-in methods',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Connect more than one method so you can recover access without creating a second profile.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: connected
                .map(
                  (AuthProviderType provider) => Chip(
                    avatar: Icon(_providerIcon(provider), size: 18),
                    label: Text(_providerLabel(provider)),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if (!user.usesPassword)
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) =>
                              _LinkPasswordDialog(initialEmail: user.email),
                        ),
                  icon: const Icon(Icons.password_rounded),
                  label: const Text('Add email and password'),
                ),
              if (!user.usesGoogle)
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () => ref
                            .read(authActionControllerProvider.notifier)
                            .linkGoogle(),
                  icon: const Icon(Icons.g_mobiledata_rounded),
                  label: const Text('Connect Google'),
                ),
              if (!user.usesApple)
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () => ref
                            .read(authActionControllerProvider.notifier)
                            .linkApple(),
                  icon: const Icon(Icons.apple),
                  label: const Text('Connect Apple'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionsCard extends StatelessWidget {
  const _SessionsCard({required this.user, required this.loading});

  final AuthUser user;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Active sessions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Use this after losing a device or whenever you want every device to sign in again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: loading
                ? null
                : () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) =>
                        _RevokeSessionsDialog(user: user),
                  ),
            icon: const Icon(Icons.devices_other_rounded),
            label: const Text('Sign out everywhere'),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard({required this.user, required this.loading});

  final AuthUser user;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Delete account',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Deleting your account removes authentication, your username reservation, and your ReeMove profile. This cannot be undone.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: loading
                ? null
                : () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) =>
                        _DeleteAccountDialog(user: user),
                  ),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Delete my account'),
          ),
        ],
      ),
    );
  }
}

class _LinkPasswordDialog extends ConsumerStatefulWidget {
  const _LinkPasswordDialog({this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<_LinkPasswordDialog> createState() =>
      _LinkPasswordDialogState();
}

class _LinkPasswordDialogState extends ConsumerState<_LinkPasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool linked = await ref
        .read(authActionControllerProvider.notifier)
        .linkEmailPassword(
          email: AuthValidators.normalizeEmail(_email.text),
          password: _password.text,
        );
    if (mounted && linked) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> action = ref.watch(authActionControllerProvider);
    final bool loading = action.isLoading;
    return AlertDialog(
      title: const Text('Add email and password'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                autofillHints: const <String>[AutofillHints.email],
                validator: AuthValidators.email,
                enabled: !loading,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                controller: _password,
                label: 'New password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                autofillHints: const <String>[AutofillHints.newPassword],
                validator: AuthValidators.strongPassword,
                enabled: !loading,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 150,
          child: AuthPrimaryButton(
            label: 'Connect',
            loading: loading,
            onPressed: _link,
          ),
        ),
      ],
    );
  }
}

class _RevokeSessionsDialog extends ConsumerStatefulWidget {
  const _RevokeSessionsDialog({required this.user});

  final AuthUser user;

  @override
  ConsumerState<_RevokeSessionsDialog> createState() =>
      _RevokeSessionsDialogState();
}

class _RevokeSessionsDialogState extends ConsumerState<_RevokeSessionsDialog> {
  final TextEditingController _password = TextEditingController();
  Object? _localError;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _revoke() async {
    setState(() => _localError = null);
    if (widget.user.usesPassword && _password.text.isEmpty) {
      setState(() {
        _localError = const Failure(
          message: 'Enter your current password.',
          code: 'password-required',
        );
      });
      return;
    }
    final AuthActionController controller = ref.read(
      authActionControllerProvider.notifier,
    );
    final bool reauthenticated = await _reauthenticate(
      controller,
      widget.user,
      password: _password.text,
    );
    if (!reauthenticated) {
      return;
    }
    final bool revoked = await controller.revokeSessions();
    if (mounted && revoked) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> action = ref.watch(authActionControllerProvider);
    final bool loading = action.isLoading;
    final Object? error =
        _localError ?? (action.hasError ? action.error : null);
    return AlertDialog(
      icon: const Icon(Icons.devices_other_rounded, size: 34),
      title: const Text('Sign out everywhere?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'ReeMove will verify your identity, revoke all refresh tokens, and sign out this device too.',
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              AuthErrorBanner(error: error),
            ],
            if (widget.user.usesPassword) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                controller: _password,
                label: 'Current password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                enabled: !loading,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 180,
          child: AuthPrimaryButton(
            label: 'Sign out everywhere',
            loading: loading,
            onPressed: _revoke,
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({required this.user});

  final AuthUser user;

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  Object? _localError;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _localError = null);
    if (_confirmation.text.trim().toUpperCase() != 'DELETE') {
      setState(() {
        _localError = const Failure(
          message: 'Type DELETE exactly to confirm.',
          code: 'confirmation-required',
        );
      });
      return;
    }
    if (widget.user.usesPassword && _password.text.isEmpty) {
      setState(() {
        _localError = const Failure(
          message: 'Enter your current password.',
          code: 'password-required',
        );
      });
      return;
    }

    final AuthActionController controller = ref.read(
      authActionControllerProvider.notifier,
    );
    final bool reauthenticated = await _reauthenticate(
      controller,
      widget.user,
      password: _password.text,
    );
    if (!reauthenticated) {
      return;
    }
    final bool deleted = await controller.deleteAccount();
    if (mounted && deleted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> action = ref.watch(authActionControllerProvider);
    final bool loading = action.isLoading;
    final Object? error =
        _localError ?? (action.hasError ? action.error : null);

    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.danger,
        size: 36,
      ),
      title: const Text('Permanently delete account?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'ReeMove will verify your identity before starting irreversible deletion.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (error != null) ...<Widget>[
                AuthErrorBanner(error: error),
                const SizedBox(height: AppSpacing.md),
              ],
              if (widget.user.usesPassword) ...<Widget>[
                AuthTextField(
                  controller: _password,
                  label: 'Current password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  enabled: !loading,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AuthTextField(
                controller: _confirmation,
                label: 'Type DELETE to confirm',
                prefixIcon: Icons.delete_outline_rounded,
                enabled: !loading,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 180,
          child: AuthPrimaryButton(
            label: 'Delete forever',
            loading: loading,
            onPressed: _delete,
          ),
        ),
      ],
    );
  }
}

Future<bool> _reauthenticate(
  AuthActionController controller,
  AuthUser user, {
  required String password,
}) async {
  if (user.usesPassword) {
    if (password.isEmpty) {
      return false;
    }
    return controller.reauthenticateWithPassword(password);
  }
  if (user.usesGoogle) {
    return controller.reauthenticateWithGoogle();
  }
  if (user.usesApple) {
    return controller.reauthenticateWithApple();
  }
  return false;
}

String _providerLabel(AuthProviderType provider) => switch (provider) {
  AuthProviderType.password => 'Email and password',
  AuthProviderType.google => 'Google',
  AuthProviderType.apple => 'Apple',
  AuthProviderType.unknown => 'Other',
};

IconData _providerIcon(AuthProviderType provider) => switch (provider) {
  AuthProviderType.password => Icons.password_rounded,
  AuthProviderType.google => Icons.g_mobiledata_rounded,
  AuthProviderType.apple => Icons.apple,
  AuthProviderType.unknown => Icons.key_rounded,
};
