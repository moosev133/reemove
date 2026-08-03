import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/presentation/widgets/logout_action.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/profile_edit_request.dart';
import '../../domain/entities/profile_privacy_settings.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/verification_request.dart';
import '../../domain/profile_privacy_model.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? profile = ref.watch(currentUserProfileProvider).value;
    final VerificationRequest? verification = ref
        .watch(currentVerificationRequestProvider)
        .value;
    final bool loggingOut = ref.watch(authActionControllerProvider).isLoading;
    final bool savingVisibility = ref
        .watch(profileActionControllerProvider)
        .isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile settings')),
      body: AdaptivePageBody(
        maxWidth: 720,
        slivers: <Widget>[
          if (profile != null)
            PremiumSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Account visibility',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    ProfilePrivacyModel.isPublicAccount(
                          visibility: profile.visibility,
                        )
                        ? 'Anyone can find your profile and follow you automatically.'
                        : 'Only approved followers can see your full profile and posts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.public_rounded),
                        label: Text('Public'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.lock_outline_rounded),
                        label: Text('Private account'),
                      ),
                    ],
                    selected: <bool>{
                      ProfilePrivacyModel.isPublicAccount(
                        visibility: profile.visibility,
                      ),
                    },
                    onSelectionChanged: savingVisibility
                        ? null
                        : (Set<bool> value) =>
                              _setVisibility(ref, profile, value.first),
                  ),
                ],
              ),
            ),
          if (profile != null) const SizedBox(height: AppSpacing.lg),
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
                  icon: Icons.send_outlined,
                  title: 'Sent requests',
                  subtitle: 'Follow requests waiting for approval',
                  onTap: profile == null
                      ? null
                      : () => context.push(
                          AppRoutes.profileConnections(
                            profile.uid,
                            'sentRequests',
                          ),
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
              onTap: loggingOut ? null : () => performLogout(context, ref),
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

  static Future<void> _setVisibility(
    WidgetRef ref,
    UserProfile profile,
    bool isPublic,
  ) async {
    final ProfilePrivacySettings privacy =
        ref.read(profilePrivacySettingsProvider).value ??
        ProfilePrivacySettings.defaults();
    final AccountPrivacy nextPrivacy = ProfilePrivacyModel.fromSettingsToggle(
      isPublic: isPublic,
    );
    final Visibility nextVisibility =
        ProfilePrivacyModel.legacyVisibilityEnumFor(nextPrivacy);
    if (ProfilePrivacyModel.resolve(
          legacyVisibility: profile.visibility.storageValue,
        ) ==
        nextPrivacy) {
      return;
    }
    final ProfileEditRequest request = ProfileEditRequest(
      displayName: profile.displayName,
      username: profile.username,
      bio: profile.bio,
      avatarUrl: profile.avatarUrl,
      coverUrl: profile.coverUrl,
      websiteUrl: profile.websiteUrl,
      primarySportId: profile.primarySportId,
      favoriteSportIds: profile.favoriteSportIds,
      goals: profile.goals,
      visibility: nextVisibility.storageValue,
      privacy: privacy.copyWith(
        followApprovalPolicy: isPublic
            ? FollowApprovalPolicy.automatic
            : FollowApprovalPolicy.approvalRequired,
      ),
      professional: ProfessionalProfileInput(
        headline: profile.professionalDetails.headline,
        organization: profile.professionalDetails.organization,
        positionOrCategory: profile.professionalDetails.positionOrCategory,
        yearsExperience: profile.professionalDetails.yearsExperience,
        specialties: profile.professionalDetails.specialties,
        acceptingClients: profile.professionalDetails.acceptingClients,
      ),
    );
    await ref
        .read(profileActionControllerProvider.notifier)
        .updateProfile(request);
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
