import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/presentation/widgets/logout_action.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/verification_request.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? profile = ref.watch(currentUserProfileProvider).value;
    final VerificationRequest? verification = ref
        .watch(currentVerificationRequestProvider)
        .value;
    final bool loggingOut = ref.watch(authActionControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile settings')),
      body: AdaptivePageBody(
        maxWidth: 720,
        slivers: <Widget>[
          PremiumSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _SettingsTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit profile',
                  subtitle:
                      'Identity, bio, sports, images, and professional details',
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Privacy and interactions',
                  subtitle:
                      'Followers, messages, mentions, tags, and discoverability',
                  onTap: () => context.push(AppRoutes.profilePrivacy),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Follow requests',
                  subtitle: 'Review people waiting for approval',
                  onTap: profile == null
                      ? null
                      : () => context.push(
                          AppRoutes.profileConnections(profile.uid, 'requests'),
                        ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.block_outlined,
                  title: 'Blocked profiles',
                  subtitle: 'Review and unblock accounts',
                  onTap: () => context.push(AppRoutes.blockedProfiles),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.smart_toy_outlined,
                  title: 'ReeMove AI',
                  subtitle: 'Coach, plans, matchmaker, and content tools',
                  onTap: () => context.push(AppRoutes.aiHub),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PremiumSurface(
            padding: EdgeInsets.zero,
            child: _SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              subtitle: 'Sign out of ReeMove on this device',
              onTap: loggingOut
                  ? null
                  : () => performLogout(context, ref),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PremiumSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _SettingsTile(
                  icon: Icons.verified_outlined,
                  title: profile?.isVerified == true
                      ? 'Verified profile'
                      : 'Profile verification',
                  subtitle: _verificationSubtitle(profile, verification),
                  onTap: () => context.push(AppRoutes.profileVerification),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.security_outlined,
                  title: 'Account and security',
                  subtitle:
                      'Sign-in methods, sessions, data, and account deletion',
                  onTap: () => context.push(AppRoutes.accountSecurity),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _verificationSubtitle(
    UserProfile? profile,
    VerificationRequest? request,
  ) {
    if (profile?.isVerified == true) {
      return 'Your ${profile!.verificationType.name} identity is verified.';
    }
    return switch (request?.status) {
      VerificationRequestStatus.pending => 'Your request is under review.',
      VerificationRequestStatus.rejected =>
        'Review the decision or submit updated evidence.',
      _ => 'Apply as an athlete, trainer, or sports business.',
    };
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
