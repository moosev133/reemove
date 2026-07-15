import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/notification_providers.dart';
import '../../domain/entities/notification_preferences.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UnifiedNotificationPreferences> preferences = ref.watch(
      notificationPreferencesProvider,
    );
    final AsyncValue<void> action = ref.watch(
      notificationActionControllerProvider,
    );
    ref.listen<AsyncValue<void>>(notificationActionControllerProvider, (
      AsyncValue<void>? previous,
      AsyncValue<void> next,
    ) {
      if (next.hasError && !identical(previous?.error, next.error)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppErrorView(
          title: 'Settings could not load',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(notificationPreferencesProvider),
        ),
        data: (UnifiedNotificationPreferences value) => AbsorbPointer(
          absorbing: action.isLoading,
          child: AdaptivePageBody(
            restorationId: 'notification_settings',
            slivers: <Widget>[
              const AppPageHeader(
                eyebrow: 'Your attention, protected',
                title: 'Choose what reaches you',
                subtitle:
                    'All important activity remains in your private inbox. These controls decide which updates also send a push notification.',
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text('Push notifications'),
                      subtitle: const Text(
                        'Master control for this ReeMove account.',
                      ),
                      value: value.masterEnabled,
                      onChanged: (bool enabled) => unawaited(
                        _setMaster(ref, value.copyWith(masterEnabled: enabled)),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.visibility_outlined),
                      title: const Text('Show notification previews'),
                      subtitle: const Text(
                        'Turn off to hide message and activity details on the lock screen.',
                      ),
                      value: value.showPreviews,
                      onChanged: value.masterEnabled
                          ? (bool enabled) => unawaited(
                              _save(ref, value.copyWith(showPreviews: enabled)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Categories', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              PremiumSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _categoryTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'Social activity',
                      subtitle:
                          'Followers, requests, likes, comments, and reposts.',
                      value: value.activity,
                      enabled: value.masterEnabled,
                      onChanged: (bool next) =>
                          unawaited(_save(ref, value.copyWith(activity: next))),
                    ),
                    _divider,
                    _categoryTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Messages',
                      subtitle: 'Direct and group conversation updates.',
                      value: value.messages,
                      enabled: value.masterEnabled,
                      onChanged: (bool next) =>
                          unawaited(_save(ref, value.copyWith(messages: next))),
                    ),
                    _divider,
                    _categoryTile(
                      icon: Icons.event_outlined,
                      title: 'Events',
                      subtitle: 'Attendance, cancellations, and event changes.',
                      value: value.events,
                      enabled: value.masterEnabled,
                      onChanged: (bool next) =>
                          unawaited(_save(ref, value.copyWith(events: next))),
                    ),
                    _divider,
                    _categoryTile(
                      icon: Icons.emoji_events_outlined,
                      title: 'Challenges',
                      subtitle:
                          'Progress reviews, rewards, and opted-in reminders.',
                      value: value.challenges,
                      enabled: value.masterEnabled,
                      onChanged: (bool next) => unawaited(
                        _save(ref, value.copyWith(challenges: next)),
                      ),
                    ),
                    _divider,
                    _categoryTile(
                      icon: Icons.storefront_outlined,
                      title: 'Marketplace',
                      subtitle:
                          'Listing approvals, expiry, and lifecycle updates.',
                      value: value.marketplace,
                      enabled: value.masterEnabled,
                      onChanged: (bool next) => unawaited(
                        _save(ref, value.copyWith(marketplace: next)),
                      ),
                    ),
                    _divider,
                    _categoryTile(
                      icon: Icons.shield_outlined,
                      title: 'Account and safety',
                      subtitle: 'Important security and service notices.',
                      value: value.system,
                      enabled: value.masterEnabled,
                      onChanged: (bool next) =>
                          unawaited(_save(ref, value.copyWith(system: next))),
                    ),
                    _divider,
                    _categoryTile(
                      icon: Icons.new_releases_outlined,
                      title: 'Product updates',
                      subtitle:
                          'Optional announcements about new ReeMove features.',
                      value: value.productUpdates,
                      enabled: value.masterEnabled,
                      onChanged: (bool next) => unawaited(
                        _save(ref, value.copyWith(productUpdates: next)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Quiet hours',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              PremiumSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.bedtime_outlined),
                      title: const Text('Pause push notifications'),
                      subtitle: const Text(
                        'Updates still appear in Activity and are delivered after quiet hours.',
                      ),
                      value: value.quietHours.enabled,
                      onChanged: value.masterEnabled
                          ? (bool enabled) => unawaited(
                              _save(
                                ref,
                                value.copyWith(
                                  quietHours: value.quietHours.copyWith(
                                    enabled: enabled,
                                    utcOffsetMinutes:
                                        DateTime.now().timeZoneOffset.inMinutes,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.nights_stay_outlined),
                      title: const Text('Starts'),
                      trailing: Text(_timeLabel(value.quietHours.startMinutes)),
                      enabled: value.masterEnabled && value.quietHours.enabled,
                      onTap: () => unawaited(
                        _pickTime(context, ref, value, isStart: true),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.wb_sunny_outlined),
                      title: const Text('Ends'),
                      trailing: Text(_timeLabel(value.quietHours.endMinutes)),
                      enabled: value.masterEnabled && value.quietHours.enabled,
                      onTap: () => unawaited(
                        _pickTime(context, ref, value, isStart: false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  static Widget get _divider => const Divider(height: 1);

  Widget _categoryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    UnifiedNotificationPreferences value, {
    required bool isStart,
  }) async {
    final int current = isStart
        ? value.quietHours.startMinutes
        : value.quietHours.endMinutes;
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (selected == null || !context.mounted) {
      return;
    }
    final int minutes = selected.hour * 60 + selected.minute;
    final NotificationQuietHours quiet = isStart
        ? value.quietHours.copyWith(
            startMinutes: minutes,
            utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
          )
        : value.quietHours.copyWith(
            endMinutes: minutes,
            utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
          );
    await _save(ref, value.copyWith(quietHours: quiet));
  }

  Future<void> _setMaster(
    WidgetRef ref,
    UnifiedNotificationPreferences value,
  ) async {
    await ref
        .read(notificationActionControllerProvider.notifier)
        .setMasterEnabled(value);
  }

  Future<void> _save(
    WidgetRef ref,
    UnifiedNotificationPreferences value,
  ) async {
    await ref
        .read(notificationActionControllerProvider.notifier)
        .updatePreferences(value);
  }
}

String _timeLabel(int minutes) {
  final int normalized = minutes.clamp(0, 1439).toInt();
  final int hour = normalized ~/ 60;
  final int minute = normalized % 60;
  final String period = hour >= 12 ? 'PM' : 'AM';
  final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}
