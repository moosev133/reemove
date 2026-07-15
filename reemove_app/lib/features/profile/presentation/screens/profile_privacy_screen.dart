import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/profile_privacy_settings.dart';

class ProfilePrivacyScreen extends ConsumerStatefulWidget {
  const ProfilePrivacyScreen({super.key});

  @override
  ConsumerState<ProfilePrivacyScreen> createState() =>
      _ProfilePrivacyScreenState();
}

class _ProfilePrivacyScreenState extends ConsumerState<ProfilePrivacyScreen> {
  ProfilePrivacySettings? _draft;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ProfilePrivacySettings> value = ref.watch(
      profilePrivacySettingsProvider,
    );
    final bool saving = ref.watch(profileActionControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy and interactions'),
        actions: <Widget>[
          TextButton(
            onPressed: saving || _draft == null ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            Center(child: Text('$error')),
        data: (ProfilePrivacySettings settings) {
          _draft ??= settings;
          final ProfilePrivacySettings draft = _draft!;
          return AdaptivePageBody(
            maxWidth: 760,
            slivers: <Widget>[
              PremiumSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Connections',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<FollowApprovalPolicy>(
                      initialValue: draft.followApprovalPolicy,
                      decoration: const InputDecoration(
                        labelText: 'New followers',
                        prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                      ),
                      items: const <DropdownMenuItem<FollowApprovalPolicy>>[
                        DropdownMenuItem<FollowApprovalPolicy>(
                          value: FollowApprovalPolicy.automatic,
                          child: Text('Accept automatically'),
                        ),
                        DropdownMenuItem<FollowApprovalPolicy>(
                          value: FollowApprovalPolicy.approvalRequired,
                          child: Text('Require approval'),
                        ),
                      ],
                      onChanged: (FollowApprovalPolicy? item) {
                        if (item != null) {
                          _set(draft.copyWith(followApprovalPolicy: item));
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AudienceField(
                      label: 'Messages',
                      icon: Icons.chat_bubble_outline_rounded,
                      value: draft.messageAudience,
                      onChanged: (ProfileAudience item) =>
                          _set(draft.copyWith(messageAudience: item)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AudienceField(
                      label: 'Mentions',
                      icon: Icons.alternate_email_rounded,
                      value: draft.mentionAudience,
                      onChanged: (ProfileAudience item) =>
                          _set(draft.copyWith(mentionAudience: item)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AudienceField(
                      label: 'Tags',
                      icon: Icons.sell_outlined,
                      value: draft.tagAudience,
                      onChanged: (ProfileAudience item) =>
                          _set(draft.copyWith(tagAudience: item)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _Toggle(
                      title: 'Show activity status',
                      subtitle: 'Let permitted people see when you are active.',
                      value: draft.showActivityStatus,
                      onChanged: (bool value) =>
                          _set(draft.copyWith(showActivityStatus: value)),
                    ),
                    const Divider(height: 1),
                    _Toggle(
                      title: 'Show sport levels',
                      subtitle: 'Display your skill level for selected sports.',
                      value: draft.showSportLevels,
                      onChanged: (bool value) =>
                          _set(draft.copyWith(showSportLevels: value)),
                    ),
                    const Divider(height: 1),
                    _Toggle(
                      title: 'Show goals',
                      subtitle: 'Display your sports goals on your profile.',
                      value: draft.showGoals,
                      onChanged: (bool value) =>
                          _set(draft.copyWith(showGoals: value)),
                    ),
                    const Divider(height: 1),
                    _Toggle(
                      title: 'Show approximate location',
                      subtitle:
                          'Only your coarse public location can be shown.',
                      value: draft.showLocation,
                      onChanged: (bool value) =>
                          _set(draft.copyWith(showLocation: value)),
                    ),
                    const Divider(height: 1),
                    _Toggle(
                      title: 'Show follower lists',
                      subtitle:
                          'Allow permitted profile visitors to open these lists.',
                      value: draft.showFollowerLists,
                      onChanged: (bool value) =>
                          _set(draft.copyWith(showFollowerLists: value)),
                    ),
                    const Divider(height: 1),
                    _Toggle(
                      title: 'Hide like counts',
                      subtitle:
                          'Hide counts on your content from other people.',
                      value: draft.hideLikeCounts,
                      onChanged: (bool value) =>
                          _set(draft.copyWith(hideLikeCounts: value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _Toggle(
                      title: 'Discoverable by username',
                      subtitle:
                          'Allow your profile to appear in username search.',
                      value: draft.discoverableByUsername,
                      onChanged: (bool value) =>
                          _set(draft.copyWith(discoverableByUsername: value)),
                    ),
                    const Divider(height: 1),
                    _Toggle(
                      title: 'Personalized suggestions',
                      subtitle:
                          'Use your sports and activity for relevant suggestions.',
                      value: draft.personalizedSuggestions,
                      onChanged: (bool value) =>
                          _set(draft.copyWith(personalizedSuggestions: value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save privacy settings'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _set(ProfilePrivacySettings value) => setState(() => _draft = value);

  Future<void> _save() async {
    final ProfilePrivacySettings? draft = _draft;
    if (draft == null) {
      return;
    }
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .updatePrivacy(draft);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Privacy settings saved.'
              : '${ref.read(profileActionControllerProvider).error}',
        ),
      ),
    );
  }
}

class _AudienceField extends StatelessWidget {
  const _AudienceField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final ProfileAudience value;
  final ValueChanged<ProfileAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ProfileAudience>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: const <DropdownMenuItem<ProfileAudience>>[
        DropdownMenuItem<ProfileAudience>(
          value: ProfileAudience.everyone,
          child: Text('Everyone'),
        ),
        DropdownMenuItem<ProfileAudience>(
          value: ProfileAudience.followers,
          child: Text('People you follow'),
        ),
        DropdownMenuItem<ProfileAudience>(
          value: ProfileAudience.noOne,
          child: Text('No one'),
        ),
      ],
      onChanged: (ProfileAudience? item) {
        if (item != null) {
          onChanged(item);
        }
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
