import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/domain/value_objects/content_policy.dart' as policy;
import '../../../profile/domain/entities/user_profile.dart';
import '../../../sports/shared/domain/entities/sport_definition.dart';
import '../../application/onboarding_providers.dart';
import '../../application/onboarding_view_state.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../onboarding_catalog.dart';
import 'avatar_selector.dart';
import 'preference_switch_tile.dart';
import 'selectable_option_card.dart';
import 'sport_icon.dart';

class OnboardingStepContent extends StatelessWidget {
  const OnboardingStepContent({
    required this.viewState,
    required this.controller,
    required this.onChooseAvatar,
    super.key,
  });

  final OnboardingViewState viewState;
  final OnboardingController controller;
  final VoidCallback onChooseAvatar;

  @override
  Widget build(BuildContext context) {
    return switch (viewState.draft.currentStep) {
      OnboardingStep.profile => _ProfileStep(
        state: viewState,
        onChooseAvatar: onChooseAvatar,
      ),
      OnboardingStep.birthday => _BirthdayStep(
        state: viewState,
        onChanged: controller.setBirthday,
      ),
      OnboardingStep.sports => _SportsStep(
        state: viewState,
        onToggle: controller.toggleSport,
      ),
      OnboardingStep.levels => _LevelsStep(
        state: viewState,
        onChanged: controller.setSportLevel,
      ),
      OnboardingStep.goals => _GoalsStep(
        state: viewState,
        onToggle: controller.toggleGoal,
      ),
      OnboardingStep.location => _LocationStep(
        state: viewState,
        onRequest: controller.requestLocation,
        onOpenAppSettings: controller.openApplicationSettings,
        onOpenLocationSettings: controller.openDeviceLocationSettings,
      ),
      OnboardingStep.discovery => _DiscoveryStep(
        value: viewState.draft.discovery,
        onChanged: controller.setDiscovery,
      ),
      OnboardingStep.accessibility => _AccessibilityStep(
        value: viewState.draft.accessibility,
        onChanged: controller.setAccessibility,
      ),
      OnboardingStep.notifications => _NotificationsStep(
        state: viewState,
        onChanged: controller.setNotifications,
        onRequestPermission: controller.requestNotificationPermission,
      ),
      OnboardingStep.review => _ReviewStep(state: viewState),
    };
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({required this.state, required this.onChooseAvatar});

  final OnboardingViewState state;
  final VoidCallback onChooseAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AvatarSelector(
          displayName: state.profile.displayName,
          avatarUrl: state.draft.avatarUrl,
          uploading: state.isUploadingAvatar,
          onPressed: onChooseAvatar,
        ),
        const SizedBox(height: AppSpacing.xl),
        _InfoTile(
          icon: Icons.alternate_email_rounded,
          title: '@${state.profile.username}',
          subtitle:
              'Your username is reserved. You can update profile details later.',
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoTile(
          icon: Icons.verified_user_outlined,
          title: 'Account protected',
          subtitle:
              'Your public profile cannot change server-owned identity or safety fields.',
        ),
      ],
    );
  }
}

class _BirthdayStep extends StatelessWidget {
  const _BirthdayStep({required this.state, required this.onChanged});

  final OnboardingViewState state;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime lastDate = DateTime(
      now.year - state.policy.minimumAge,
      now.month,
      now.day,
    );
    final DateTime firstDate = DateTime(
      now.year - state.policy.maximumAge,
      now.month,
      now.day,
    );
    final DateTime? selected = state.draft.dateOfBirth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Birthday', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () async {
            final DateTime? value = await showDatePicker(
              context: context,
              initialDate: selected ?? lastDate,
              firstDate: firstDate,
              lastDate: lastDate,
              helpText: 'Select your birthday',
            );
            if (value != null) {
              onChanged(value);
            }
          },
          icon: const Icon(Icons.cake_outlined),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              selected == null
                  ? 'Choose your birthday'
                  : MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(selected),
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PrivacyCard(
          icon: Icons.lock_outline_rounded,
          title: 'Your birthday stays private',
          body:
              'ReeMove stores it in protected account data and uses only an age band for age-appropriate safety.',
        ),
        const SizedBox(height: AppSpacing.md),
        _PrivacyCard(
          icon: Icons.gavel_outlined,
          title: 'Legal agreements confirmed',
          body:
              'Terms ${state.policy.termsVersion} and Privacy Policy ${state.policy.privacyVersion} were accepted during account setup. Completion checks that they are still current.',
        ),
      ],
    );
  }
}

class _SportsStep extends StatelessWidget {
  const _SportsStep({required this.state, required this.onToggle});

  final OnboardingViewState state;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (state.sports.isEmpty) {
      return const _PrivacyCard(
        icon: Icons.sports_rounded,
        title: 'Sports catalog unavailable',
        body: 'Check the Firebase seed data or active sports configuration.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '${state.draft.favoriteSportIds.length}/8 selected',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            const Text('Choose at least one'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.sports.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisExtent: 116,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemBuilder: (BuildContext context, int index) {
            final SportDefinition sport = state.sports[index];
            final bool selected = state.draft.favoriteSportIds.contains(
              sport.id,
            );
            return SelectableOptionCard(
              selected: selected,
              icon: SportIcon.fromKey(sport.iconKey),
              title: sport.displayName('en'),
              subtitle: selected
                  ? 'Included in your sports profile'
                  : 'Tap to personalize discovery',
              onTap: () => onToggle(sport.id),
            );
          },
        ),
      ],
    );
  }
}

class _LevelsStep extends StatelessWidget {
  const _LevelsStep({required this.state, required this.onChanged});

  final OnboardingViewState state;
  final void Function(String sportId, SportLevel level) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: state.draft.favoriteSportIds
          .map((String sportId) {
            final SportDefinition? sport = _sportById(state.sports, sportId);
            final SportLevel? value = state.draft.sportLevels[sportId];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      child: Icon(SportIcon.fromKey(sport?.iconKey ?? sportId)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        sport?.displayName('en') ?? sportId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<SportLevel>(
                        initialValue: value,
                        hint: const Text('Choose level'),
                        items: SportLevel.values
                            .map(
                              (SportLevel level) =>
                                  DropdownMenuItem<SportLevel>(
                                    value: level,
                                    child: Text(_levelLabel(level)),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (SportLevel? level) {
                          if (level != null) {
                            onChanged(sportId, level);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({required this.state, required this.onToggle});

  final OnboardingViewState state;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${state.draft.goals.length}/8 selected',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        ...OnboardingCatalog.goals.map(
          (OnboardingGoalOption option) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SelectableOptionCard(
              selected: state.draft.goals.contains(option.id),
              icon: option.icon,
              title: option.label,
              subtitle: option.description,
              onTap: () => onToggle(option.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.state,
    required this.onRequest,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
  });

  final OnboardingViewState state;
  final VoidCallback onRequest;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final GeoLocationSummary summary = _locationSummary(state.draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                AppColors.brand.withValues(alpha: 0.16),
                AppColors.info.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: <Widget>[
              Icon(summary.icon, size: 54, color: summary.color),
              const SizedBox(height: AppSpacing.md),
              Text(
                summary.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                summary.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: state.isRequestingLocation ? null : onRequest,
          icon: state.isRequestingLocation
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded),
          label: Text(
            state.draft.location == null
                ? 'Use my current location'
                : 'Refresh location',
          ),
        ),
        if (state.draft.locationPermission ==
            PermissionDecision.deniedForever) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onOpenAppSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open app settings'),
          ),
        ],
        if (state.draft.locationPermission ==
            PermissionDecision.unavailable) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onOpenLocationSettings,
            icon: const Icon(Icons.location_disabled_outlined),
            label: const Text('Open location settings'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _PrivacyCard(
          icon: Icons.blur_on_rounded,
          title: 'Public location is deliberately coarse',
          body:
              'Your exact coordinates stay in private preferences. Public discovery stores only an area-level position to reduce location exposure.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Location is optional. You can continue without granting permission.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DiscoveryStep extends StatelessWidget {
  const _DiscoveryStep({required this.value, required this.onChanged});

  final DiscoveryPreferences value;
  final ValueChanged<DiscoveryPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Discovery radius',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '${value.radiusKm.round()} km',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        Slider(
          value: value.radiusKm.clamp(1, 200).toDouble(),
          min: 1,
          max: 200,
          divisions: 199,
          label: '${value.radiusKm.round()} km',
          onChanged: (double radius) =>
              onChanged(value.copyWith(radiusKm: radius)),
        ),
        const SizedBox(height: AppSpacing.md),
        PreferenceSwitchTile(
          value: value.showNearbyPeople,
          title: 'Show nearby people',
          subtitle: 'Allow eligible users to discover your profile by area.',
          icon: Icons.people_outline_rounded,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(showNearbyPeople: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.recommendEvents,
          title: 'Recommend nearby events',
          subtitle:
              'Prioritize matches, runs, and sessions within your radius.',
          icon: Icons.event_available_outlined,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(recommendEvents: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.allowTrainerDiscovery,
          title: 'Trainer discovery',
          subtitle: 'Let verified trainers appear in your recommendations.',
          icon: Icons.sports_outlined,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(allowTrainerDiscovery: enabled)),
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<policy.Visibility>(
          initialValue: value.visibility,
          decoration: const InputDecoration(
            labelText: 'Profile visibility',
            prefixIcon: Icon(Icons.visibility_outlined),
          ),
          items: policy.Visibility.values
              .map(
                (policy.Visibility visibility) =>
                    DropdownMenuItem<policy.Visibility>(
                      value: visibility,
                      child: Text(_visibilityLabel(visibility)),
                    ),
              )
              .toList(growable: false),
          onChanged: (policy.Visibility? visibility) {
            if (visibility != null) {
              onChanged(value.copyWith(visibility: visibility));
            }
          },
        ),
      ],
    );
  }
}

class _AccessibilityStep extends StatelessWidget {
  const _AccessibilityStep({required this.value, required this.onChanged});

  final AccessibilityPreferences value;
  final ValueChanged<AccessibilityPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        PreferenceSwitchTile(
          value: value.reduceMotion,
          title: 'Reduce motion',
          subtitle: 'Use simpler transitions and fewer animated effects.',
          icon: Icons.motion_photos_off_outlined,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(reduceMotion: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.highContrast,
          title: 'Higher contrast',
          subtitle: 'Increase separation between text, controls, and surfaces.',
          icon: Icons.contrast_rounded,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(highContrast: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.largeText,
          title: 'Larger text',
          subtitle: 'Prefer a more generous text scale inside ReeMove.',
          icon: Icons.text_increase_rounded,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(largeText: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.screenReaderOptimized,
          title: 'Screen reader optimized',
          subtitle: 'Prefer explicit labels and simplified information order.',
          icon: Icons.record_voice_over_outlined,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(screenReaderOptimized: enabled)),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _PrivacyCard(
          icon: Icons.accessibility_new_rounded,
          title: 'These preferences belong to you',
          body:
              'They are stored privately and will be applied across the app as each feature is implemented.',
        ),
      ],
    );
  }
}

class _NotificationsStep extends StatelessWidget {
  const _NotificationsStep({
    required this.state,
    required this.onChanged,
    required this.onRequestPermission,
  });

  final OnboardingViewState state;
  final ValueChanged<NotificationPreferences> onChanged;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final NotificationPreferences value = state.draft.notifications;
    final bool authorized =
        value.permissionStatus == NotificationPermissionDecision.authorized ||
        value.permissionStatus == NotificationPermissionDecision.provisional;
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: authorized
                ? AppColors.success.withValues(alpha: 0.10)
                : Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                authorized
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                color: authorized ? AppColors.success : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      authorized
                          ? 'Notifications enabled'
                          : 'Notifications are optional',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _notificationStatus(value.permissionStatus),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: state.isRequestingNotifications
                    ? null
                    : onRequestPermission,
                child: state.isRequestingNotifications
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(authorized ? 'Review' : 'Enable'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PreferenceSwitchTile(
          value: value.activity,
          enabled: value.masterEnabled,
          title: 'Social activity',
          subtitle: 'Likes, comments, follows, and mentions.',
          icon: Icons.favorite_border_rounded,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(activity: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.messages,
          enabled: value.masterEnabled,
          title: 'Messages',
          subtitle: 'Direct and group conversation activity.',
          icon: Icons.chat_bubble_outline_rounded,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(messages: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.events,
          enabled: value.masterEnabled,
          title: 'Events and matches',
          subtitle: 'Invitations, changes, and upcoming sessions.',
          icon: Icons.event_outlined,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(events: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.challenges,
          enabled: value.masterEnabled,
          title: 'Challenges',
          subtitle: 'Progress reminders, rankings, and rewards.',
          icon: Icons.emoji_events_outlined,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(challenges: enabled)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PreferenceSwitchTile(
          value: value.productUpdates,
          enabled: value.masterEnabled,
          title: 'Product updates',
          subtitle: 'Optional ReeMove news. Off by default.',
          icon: Icons.campaign_outlined,
          onChanged: (bool enabled) =>
              onChanged(value.copyWith(productUpdates: enabled)),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state});

  final OnboardingViewState state;

  @override
  Widget build(BuildContext context) {
    final List<String> sportNames = state.draft.favoriteSportIds
        .map(
          (String id) => _sportById(state.sports, id)?.displayName('en') ?? id,
        )
        .toList(growable: false);
    final List<String> goalNames = state.draft.goals
        .map(
          (String id) =>
              OnboardingCatalog.goals
                  .where((OnboardingGoalOption option) => option.id == id)
                  .map((OnboardingGoalOption option) => option.label)
                  .firstOrNull ??
              id,
        )
        .toList(growable: false);
    return Column(
      children: <Widget>[
        _ReviewTile(
          icon: Icons.person_outline_rounded,
          title: '@${state.profile.username}',
          subtitle: state.draft.avatarUrl == null
              ? 'No profile photo yet'
              : 'Profile photo ready',
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewTile(
          icon: Icons.sports_rounded,
          title: sportNames.join(', '),
          subtitle:
              '${sportNames.length} favorite sport${sportNames.length == 1 ? '' : 's'}',
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewTile(
          icon: Icons.flag_outlined,
          title: goalNames.join(', '),
          subtitle:
              '${goalNames.length} personal goal${goalNames.length == 1 ? '' : 's'}',
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewTile(
          icon: Icons.location_on_outlined,
          title: state.draft.location?.locality ?? 'Location not shared',
          subtitle: state.draft.location == null
              ? 'Nearby results can be enabled later'
              : '${state.draft.discovery.radiusKm.round()} km discovery radius',
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewTile(
          icon: Icons.notifications_none_rounded,
          title: state.draft.notifications.masterEnabled
              ? 'Notifications enabled'
              : 'Notifications off',
          subtitle: 'You remain in control of every category.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const _PrivacyCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Your personalized ReeMove is ready',
          body:
              'Finishing writes a trusted server completion marker and unlocks the main app. These settings remain editable.',
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _InfoTile(icon: icon, title: title, subtitle: subtitle);
  }
}

class GeoLocationSummary {
  const GeoLocationSummary({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

GeoLocationSummary _locationSummary(OnboardingDraft draft) {
  if (draft.location != null) {
    final String place =
        draft.location!.locality ??
        draft.location!.administrativeArea ??
        draft.location!.countryCode ??
        'Location captured';
    return GeoLocationSummary(
      title: place,
      subtitle: 'Ready for nearby recommendations',
      icon: Icons.location_on_rounded,
      color: AppColors.success,
    );
  }
  return switch (draft.locationPermission) {
    PermissionDecision.deniedForever => const GeoLocationSummary(
      title: 'Location blocked',
      subtitle: 'Open app settings to grant access.',
      icon: Icons.location_off_rounded,
      color: AppColors.warning,
    ),
    PermissionDecision.denied => const GeoLocationSummary(
      title: 'Location not granted',
      subtitle: 'You can try again or continue without it.',
      icon: Icons.location_off_outlined,
      color: AppColors.warning,
    ),
    PermissionDecision.unavailable => const GeoLocationSummary(
      title: 'Location services are off',
      subtitle: 'Turn them on in device settings, then retry.',
      icon: Icons.gps_off_rounded,
      color: AppColors.warning,
    ),
    _ => const GeoLocationSummary(
      title: 'Discover what is nearby',
      subtitle: 'Permission is requested only when you tap the button.',
      icon: Icons.explore_outlined,
      color: AppColors.info,
    ),
  };
}

SportDefinition? _sportById(List<SportDefinition> sports, String id) {
  for (final SportDefinition sport in sports) {
    if (sport.id == id) {
      return sport;
    }
  }
  return null;
}

String _levelLabel(SportLevel level) => switch (level) {
  SportLevel.beginner => 'Beginner',
  SportLevel.intermediate => 'Intermediate',
  SportLevel.advanced => 'Advanced',
  SportLevel.professional => 'Professional',
};

String _visibilityLabel(policy.Visibility value) => switch (value) {
  policy.Visibility.public => 'Public',
  policy.Visibility.followers => 'Followers only',
  policy.Visibility.private => 'Private',
};

String _notificationStatus(NotificationPermissionDecision value) =>
    switch (value) {
      NotificationPermissionDecision.authorized => 'System permission granted.',
      NotificationPermissionDecision.provisional =>
        'Quiet provisional delivery is enabled.',
      NotificationPermissionDecision.denied =>
        'System permission is denied. You can continue.',
      NotificationPermissionDecision.unavailable =>
        'Notification permission is unavailable in this environment.',
      NotificationPermissionDecision.notAsked =>
        'ReeMove has not requested system permission yet.',
    };

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
