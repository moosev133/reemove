import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../messages/application/messaging_providers.dart';
import '../../../messages/domain/repositories/messaging_repository.dart';
import '../../../groups/application/groups_providers.dart';
import '../../../notifications/application/notification_providers.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/presentation/widgets/notification_tile.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/domain/entities/profile_relationship.dart';
import '../../../profile/domain/repositories/profile_social_repository.dart';

enum _ActivityFilter {
  all,
  social,
  messages,
  events,
  challenges,
  marketplace,
  account,
}

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> notifications = ref.watch(
      notificationsProvider,
    );
    final AsyncValue<void> action = ref.watch(
      notificationActionControllerProvider,
    );
    final AsyncValue<NotificationHistoryState> history = ref.watch(
      notificationHistoryProvider,
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
      appBar: AppBar(
        title: const Text('Activity'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: action.isLoading
                ? null
                : () => unawaited(
                    ref
                        .read(notificationActionControllerProvider.notifier)
                        .markAllRead(),
                  ),
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () =>
                unawaited(context.push(AppRoutes.notificationSettings)),
            icon: const Icon(Icons.tune_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More activity actions',
            onSelected: (String value) {
              if (value == 'clear_read') {
                unawaited(
                  ref
                      .read(notificationActionControllerProvider.notifier)
                      .clearRead(),
                );
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'clear_read',
                    child: Text('Clear read activity'),
                  ),
                ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(notificationUnreadCountProvider);
          ref.read(notificationHistoryProvider.notifier).reset();
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: notifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => AppErrorView(
            title: 'Activity could not load',
            message: error.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(notificationsProvider),
          ),
          data: (List<AppNotification> items) {
            final NotificationHistoryState historyState =
                history.value ?? const NotificationHistoryState();
            final Map<String, AppNotification> merged =
                <String, AppNotification>{
                  for (final AppNotification item in items) item.id: item,
                  for (final AppNotification item in historyState.items)
                    item.id: item,
                };
            final List<AppNotification> allItems = merged.values.toList()
              ..sort(
                (AppNotification left, AppNotification right) =>
                    right.latestAt.compareTo(left.latestAt),
              );
            final List<AppNotification> filtered = allItems
                .where((AppNotification item) => _matches(item, _filter))
                .toList(growable: false);
            return AdaptivePageBody(
              restorationId: 'activity_inbox',
              slivers: <Widget>[
                const AppPageHeader(
                  eyebrow: 'Your private activity inbox',
                  title: 'Everything important, in one place',
                  subtitle:
                      'Messages, social activity, event changes, challenge results, and marketplace updates are grouped here. Swipe an item left to remove it.',
                ),
                const SizedBox(height: AppSpacing.lg),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _ActivityFilter.values
                        .map((_ActivityFilter value) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: ChoiceChip(
                              label: Text(_filterLabel(value)),
                              selected: _filter == value,
                              onSelected: (_) =>
                                  setState(() => _filter = value),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (filtered.isEmpty)
                  AppEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: _filter == _ActivityFilter.all
                        ? 'No activity yet'
                        : 'Nothing in this category',
                    message: _filter == _ActivityFilter.all
                        ? 'When your ReeMove network interacts with you, it will appear here.'
                        : 'Try another filter or check back after your next sports activity.',
                  )
                else
                  ...filtered.map(
                    (AppNotification notification) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: NotificationTile(
                        notification: notification,
                        onTap: () => unawaited(_open(context, notification)),
                        onActorTap: () =>
                            unawaited(_openActorProfile(context, notification)),
                        onDelete: () => unawaited(
                          ref
                              .read(
                                notificationActionControllerProvider.notifier,
                              )
                              .delete(notification.id),
                        ),
                        onAcceptFollowRequest: _acceptRequestHandler(
                          notification,
                        ),
                        onDeclineFollowRequest: _declineRequestHandler(
                          notification,
                        ),
                        onAcceptGroupJoinRequest:
                            _acceptGroupJoinRequestHandler(notification),
                        onDeclineGroupJoinRequest:
                            _declineGroupJoinRequestHandler(notification),
                        onAcceptGroupInvitation:
                            _acceptGroupInvitationHandler(notification),
                        onDeclineGroupInvitation:
                            _declineGroupInvitationHandler(notification),
                      ),
                    ),
                  ),
                if (history.hasError) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Older activity could not load.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (historyState.hasMore &&
                    (items.length >= 50 ||
                        historyState.items.isNotEmpty)) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: FilledButton.tonalIcon(
                      onPressed: history.isLoading
                          ? null
                          : () => unawaited(
                              ref
                                  .read(notificationHistoryProvider.notifier)
                                  .loadMore(items),
                            ),
                      icon: history.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: const Text('Load older activity'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, AppNotification notification) async {
    if (notification.isUnread) {
      await ref
          .read(notificationActionControllerProvider.notifier)
          .markRead(notification.id);
    }
    if (!context.mounted) {
      return;
    }
    context.go(AppRoutes.normalizeDeepLinkLocation(notification.route));
  }

  Future<void> _openActorProfile(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (notification.isUnread) {
      await ref
          .read(notificationActionControllerProvider.notifier)
          .markRead(notification.id);
    }
    if (!context.mounted) {
      return;
    }
    final NotificationActor? actor = notification.actors.isEmpty
        ? null
        : notification.actors.first;
    final String? username = actor?.username.trim();
    if (username != null && username.isNotEmpty) {
      context.go(AppRoutes.publicProfile(username));
      return;
    }
    context.go(AppRoutes.normalizeDeepLinkLocation(notification.route));
  }

  VoidCallback? _acceptRequestHandler(AppNotification notification) {
    if (_canRespondToFollowRequest(notification)) {
      return () =>
          unawaited(_respondToFollowRequest(notification, accept: true));
    }
    if (_canRespondToMessageRequest(notification)) {
      return () =>
          unawaited(_respondToMessageRequest(notification, accept: true));
    }
    return null;
  }

  VoidCallback? _declineRequestHandler(AppNotification notification) {
    if (_canRespondToFollowRequest(notification)) {
      return () =>
          unawaited(_respondToFollowRequest(notification, accept: false));
    }
    if (_canRespondToMessageRequest(notification)) {
      return () =>
          unawaited(_respondToMessageRequest(notification, accept: false));
    }
    return null;
  }

  VoidCallback? _acceptGroupJoinRequestHandler(
    AppNotification notification,
  ) {
    if (notification.kind != AppNotificationKind.groupJoinRequest) {
      return null;
    }
    final String? groupId = notification.data['groupId'];
    final String? requesterId = notification.data['requesterId'];
    if (groupId == null || groupId.isEmpty) return null;
    if (requesterId == null || requesterId.isEmpty) return null;
    final String? status = notification.data['status'];
    if (status != null && status.isNotEmpty && status != 'pending') {
      return null;
    }
    return () => unawaited(
          _respondToGroupJoinRequest(
            notification,
            accept: true,
          ),
        );
  }

  VoidCallback? _declineGroupJoinRequestHandler(
    AppNotification notification,
  ) {
    if (notification.kind != AppNotificationKind.groupJoinRequest) {
      return null;
    }
    final String? groupId = notification.data['groupId'];
    final String? requesterId = notification.data['requesterId'];
    if (groupId == null || groupId.isEmpty) return null;
    if (requesterId == null || requesterId.isEmpty) return null;
    final String? status = notification.data['status'];
    if (status != null && status.isNotEmpty && status != 'pending') {
      return null;
    }
    return () => unawaited(
          _respondToGroupJoinRequest(
            notification,
            accept: false,
          ),
        );
  }

  VoidCallback? _acceptGroupInvitationHandler(
    AppNotification notification,
  ) {
    if (notification.kind != AppNotificationKind.groupInvitation) {
      return null;
    }
    final String? groupId = notification.data['groupId'];
    if (groupId == null || groupId.isEmpty) return null;
    final String? status = notification.data['status'];
    if (status != null && status.isNotEmpty && status != 'pending') {
      return null;
    }
    return () => unawaited(
          _respondToGroupInvitation(
            notification,
            accept: true,
          ),
        );
  }

  VoidCallback? _declineGroupInvitationHandler(
    AppNotification notification,
  ) {
    if (notification.kind != AppNotificationKind.groupInvitation) {
      return null;
    }
    final String? groupId = notification.data['groupId'];
    if (groupId == null || groupId.isEmpty) return null;
    final String? status = notification.data['status'];
    if (status != null && status.isNotEmpty && status != 'pending') {
      return null;
    }
    return () => unawaited(
          _respondToGroupInvitation(
            notification,
            accept: false,
          ),
        );
  }

  bool _canRespondToFollowRequest(AppNotification notification) {
    if (notification.kind != AppNotificationKind.followRequest) {
      return false;
    }
    if (notification.entityId == null || notification.entityId!.isEmpty) {
      return false;
    }
    final String? status = notification.data['status'];
    return status == null || status.isEmpty || status == 'pending';
  }

  bool _canRespondToMessageRequest(AppNotification notification) {
    if (notification.kind != AppNotificationKind.messageRequest) {
      return false;
    }
    if (notification.entityId == null || notification.entityId!.isEmpty) {
      return false;
    }
    final String? status = notification.data['status'];
    return status == null || status.isEmpty || status == 'pending';
  }

  Future<void> _respondToFollowRequest(
    AppNotification notification, {
    required bool accept,
  }) async {
    final String? requesterId = notification.entityId;
    if (requesterId == null || requesterId.isEmpty) {
      return;
    }
    final ProfileSocialRepository social = ref.read(
      profileSocialRepositoryProvider,
    );
    final Result<ProfileRelationship> result = accept
        ? await social.acceptRequest(requesterId)
        : await social.declineRequest(requesterId);
    result.when(
      success: (_) {
        unawaited(
          ref
              .read(notificationActionControllerProvider.notifier)
              .markRead(notification.id),
        );
        unawaited(
          ref
              .read(notificationActionControllerProvider.notifier)
              .delete(notification.id),
        );
        ref.invalidate(notificationsProvider);
        ref.invalidate(notificationUnreadCountProvider);
        ref.invalidate(profileConnectionsProvider);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Follow request accepted.' : 'Follow request declined.',
            ),
          ),
        );
      },
      failure: (Failure failure) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _respondToMessageRequest(
    AppNotification notification, {
    required bool accept,
  }) async {
    final String? requesterId = notification.entityId;
    if (requesterId == null || requesterId.isEmpty) {
      return;
    }
    final MessagingRepository messaging = ref.read(messagingRepositoryProvider);
    final Result<String?> result = await messaging.respondToMessageRequest(
      requesterId: requesterId,
      decision: accept ? 'accept' : 'decline',
    );
    result.when(
      success: (String? conversationId) {
        unawaited(
          ref
              .read(notificationActionControllerProvider.notifier)
              .markRead(notification.id),
        );
        unawaited(
          ref
              .read(notificationActionControllerProvider.notifier)
              .delete(notification.id),
        );
        ref.invalidate(notificationsProvider);
        ref.invalidate(notificationUnreadCountProvider);
        if (!mounted) {
          return;
        }
        if (accept && conversationId != null && conversationId.isNotEmpty) {
          context.go(AppRoutes.conversation(conversationId));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Message request accepted.'
                  : 'Message request declined.',
            ),
          ),
        );
      },
      failure: (Failure failure) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _respondToGroupJoinRequest(
    AppNotification notification, {
    required bool accept,
  }) async {
    final String? groupId = notification.data['groupId'];
    final String? requesterId = notification.data['requesterId'];
    if (groupId == null || groupId.isEmpty) return;
    if (requesterId == null || requesterId.isEmpty) return;

    final Result<void> result = await ref
        .read(groupsRepositoryProvider)
        .respondToJoinRequest(
      groupId: groupId,
      requesterId: requesterId,
      approve: accept,
    );

    result.when(
      success: (_) {
        unawaited(
          ref
              .read(notificationActionControllerProvider.notifier)
              .markRead(notification.id),
        );
        unawaited(
          ref
              .read(notificationActionControllerProvider.notifier)
              .delete(notification.id),
        );
        ref.invalidate(notificationsProvider);
        ref.invalidate(notificationUnreadCountProvider);
        ref.invalidate(groupJoinRequestsProvider(groupId));
        ref.invalidate(groupMembersProvider(groupId));
        ref.invalidate(groupProvider(groupId));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Join request accepted.' : 'Join request declined.',
            ),
          ),
        );
      },
      failure: (Failure failure) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  Future<void> _respondToGroupInvitation(
    AppNotification notification, {
    required bool accept,
  }) async {
    final String? groupId = notification.data['groupId'];
    if (groupId == null || groupId.isEmpty) return;

    final Result<void> result = await ref
        .read(groupsRepositoryProvider)
        .respondToGroupInvitation(
      groupId: groupId,
      accept: accept,
    );

    result.when(
      success: (_) {
        unawaited(
          ref
              .read(notificationActionControllerProvider.notifier)
              .markRead(notification.id),
        );
        unawaited(
          ref
              .read(notificationActionControllerProvider.notifier)
              .delete(notification.id),
        );
        ref.invalidate(notificationsProvider);
        ref.invalidate(notificationUnreadCountProvider);
        ref.invalidate(myGroupInvitationsProvider);
        ref.invalidate(myGroupsProvider);
        ref.invalidate(groupProvider(groupId));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Invitation accepted.' : 'Invitation declined.',
            ),
          ),
        );
      },
      failure: (Failure failure) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }
}

bool _matches(AppNotification notification, _ActivityFilter filter) =>
    switch (filter) {
      _ActivityFilter.all => true,
      _ActivityFilter.social =>
        notification.category == AppNotificationCategory.activity,
      _ActivityFilter.messages =>
        notification.category == AppNotificationCategory.messages,
      _ActivityFilter.events =>
        notification.category == AppNotificationCategory.events,
      _ActivityFilter.challenges =>
        notification.category == AppNotificationCategory.challenges,
      _ActivityFilter.marketplace =>
        notification.category == AppNotificationCategory.marketplace,
      _ActivityFilter.account =>
        notification.category == AppNotificationCategory.system ||
            notification.category == AppNotificationCategory.productUpdates,
    };

String _filterLabel(_ActivityFilter filter) => switch (filter) {
  _ActivityFilter.all => 'All',
  _ActivityFilter.social => 'Social',
  _ActivityFilter.messages => 'Messages',
  _ActivityFilter.events => 'Events',
  _ActivityFilter.challenges => 'Challenges',
  _ActivityFilter.marketplace => 'Marketplace',
  _ActivityFilter.account => 'Account',
};
