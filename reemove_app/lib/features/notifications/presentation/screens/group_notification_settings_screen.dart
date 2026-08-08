import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../groups/application/groups_providers.dart';
import '../../application/group_notification_providers.dart';
import '../../domain/entities/group_notification_preferences.dart';
import '../../../groups/domain/entities/group.dart';

class GroupNotificationSettingsScreen extends ConsumerWidget {
  const GroupNotificationSettingsScreen({
    required this.groupId,
    super.key,
  });

  final String groupId;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    GroupNotificationPreferences newPrefs,
  ) async {
    final GroupNotificationActionController controller = ref
        .read(groupNotificationActionControllerProvider.notifier);
    final bool ok = await controller.update(
      groupId: groupId,
      preferences: newPrefs,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update notification settings.'),
        ),
      );
      return;
    }
    ref.invalidate(groupNotificationPreferencesProvider(groupId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Group> groupValue = ref.watch(groupProvider(groupId));
    final AsyncValue<GroupNotificationPreferences> prefsValue =
        ref.watch(
          groupNotificationPreferencesProvider(groupId),
        );
    final AsyncValue<void> action =
        ref.watch(groupNotificationActionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Group notifications')),
      body: groupValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppErrorView(
          title: 'Group unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(groupProvider(groupId)),
        ),
        data: (Group group) {
          if (!group.isMember) {
            return const Center(
              child: AppEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Join to configure notifications',
                message: 'Member notification preferences are only available to active group members.',
              ),
            );
          }
          return prefsValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace _) => AppErrorView(
              title: 'Could not load preferences',
              message: error.toString(),
              actionLabel: 'Retry',
              onAction: () =>
                  ref.invalidate(groupNotificationPreferencesProvider(groupId)),
            ),
            data: (GroupNotificationPreferences prefs) {
              final bool muted = prefs.muted;
              final bool canEdit = !action.isLoading;

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  PremiumSurface(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mute this group'),
                          subtitle: const Text('Disable all notification categories for this group.'),
                          value: prefs.muted,
                          onChanged: canEdit
                              ? (bool value) => unawaited(
                                    _save(
                                      context,
                                      ref,
                                      prefs.copyWith(muted: value),
                                    ),
                                  )
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Member chat'),
                          subtitle: const Text('Direct messages in member chat channels.'),
                          value: prefs.memberChatEnabled,
                          onChanged: canEdit && muted != true
                              ? (bool value) => unawaited(
                                    _save(
                                      context,
                                      ref,
                                      prefs.copyWith(
                                        memberChatEnabled: value,
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Announcements'),
                          subtitle: const Text('Owner/admin announcements in announcements channel.'),
                          value: prefs.announcementsEnabled,
                          onChanged: canEdit && muted != true
                              ? (bool value) => unawaited(
                                    _save(
                                      context,
                                      ref,
                                      prefs.copyWith(
                                        announcementsEnabled: value,
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Sessions & events'),
                          subtitle: const Text('Session schedule updates, cancellations, and reminders.'),
                          value: prefs.sessionsEnabled,
                          onChanged: canEdit && muted != true
                              ? (bool value) => unawaited(
                                    _save(
                                      context,
                                      ref,
                                      prefs.copyWith(
                                        sessionsEnabled: value,
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Invitations & membership'),
                          subtitle: const Text('Join requests, invitations, and membership changes.'),
                          value: prefs.invitationsEnabled,
                          onChanged: canEdit && muted != true
                              ? (bool value) => unawaited(
                                    _save(
                                      context,
                                      ref,
                                      prefs.copyWith(
                                        invitationsEnabled: value,
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (muted)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        'Group is currently muted. Unmute to edit categories.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}


