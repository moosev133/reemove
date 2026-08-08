import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/app_notification.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
    this.onActorTap,
    this.onAcceptFollowRequest,
    this.onDeclineFollowRequest,
    this.onAcceptGroupJoinRequest,
    this.onDeclineGroupJoinRequest,
    this.onAcceptGroupInvitation,
    this.onDeclineGroupInvitation,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onActorTap;
  final VoidCallback? onAcceptFollowRequest;
  final VoidCallback? onDeclineFollowRequest;
  final VoidCallback? onAcceptGroupJoinRequest;
  final VoidCallback? onDeclineGroupJoinRequest;
  final VoidCallback? onAcceptGroupInvitation;
  final VoidCallback? onDeclineGroupInvitation;

  bool get _showRequestActions {
    if (notification.kind != AppNotificationKind.followRequest &&
        notification.kind != AppNotificationKind.messageRequest) {
      return false;
    }
    if (onAcceptFollowRequest == null && onDeclineFollowRequest == null) {
      return false;
    }
    final String? status = notification.data['status'];
    if (status == null || status.isEmpty) {
      return true;
    }
    return status == 'pending';
  }

  bool get _showGroupJoinRequestActions {
    if (notification.kind != AppNotificationKind.groupJoinRequest) return false;
    if (onAcceptGroupJoinRequest == null &&
        onDeclineGroupJoinRequest == null) {
      return false;
    }
    final String? status = notification.data['status'];
    if (status == null || status.isEmpty) return true;
    return status == 'pending';
  }

  bool get _showGroupInvitationActions {
    if (notification.kind != AppNotificationKind.groupInvitation) return false;
    if (onAcceptGroupInvitation == null &&
        onDeclineGroupInvitation == null) {
      return false;
    }
    final String? status = notification.data['status'];
    if (status == null || status.isEmpty) return true;
    return status == 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final NotificationActor? actor = notification.actors.isEmpty
        ? null
        : notification.actors.first;
    return Dismissible(
      key: ValueKey<String>('notification-${notification.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Icon(
              Icons.delete_outline_rounded,
              color: colors.onErrorContainer,
            ),
          ),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: notification.isUnread
              ? Border.all(color: colors.primary.withValues(alpha: 0.45))
              : null,
        ),
        child: PremiumSurface(
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                onTap: onActorTap ?? onTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    if (actor != null)
                      AppAvatar(
                        displayName: actor.displayName,
                        imageUrl: actor.avatarUrl,
                        radius: 24,
                      )
                    else
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colors.primaryContainer,
                        child: Icon(
                          _icon(notification.kind),
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _icon(notification.kind),
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: GestureDetector(
                            onTap: onActorTap ?? onTap,
                            child: Text(
                              notification.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: notification.isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        if (notification.isUnread)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      notification.displayBody,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Text(
                          _relativeTime(notification.latestAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        if (notification.groupCount > 1) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${notification.groupCount} grouped',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                    if (_showRequestActions) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          if (onAcceptFollowRequest != null)
                            FilledButton(
                              onPressed: onAcceptFollowRequest,
                              child: const Text('Accept'),
                            ),
                          if (onAcceptFollowRequest != null &&
                              onDeclineFollowRequest != null)
                            const SizedBox(width: AppSpacing.xs),
                          if (onDeclineFollowRequest != null)
                            OutlinedButton(
                              onPressed: onDeclineFollowRequest,
                              child: const Text('Decline'),
                            ),
                        ],
                      ),
                    ],
                    if (_showGroupJoinRequestActions) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          if (onAcceptGroupJoinRequest != null)
                            FilledButton(
                              onPressed: onAcceptGroupJoinRequest,
                              child: const Text('Accept'),
                            ),
                          if (onAcceptGroupJoinRequest != null &&
                              onDeclineGroupJoinRequest != null)
                            const SizedBox(width: AppSpacing.xs),
                          if (onDeclineGroupJoinRequest != null)
                            OutlinedButton(
                              onPressed: onDeclineGroupJoinRequest,
                              child: const Text('Decline'),
                            ),
                        ],
                      ),
                    ],
                    if (_showGroupInvitationActions) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          if (onAcceptGroupInvitation != null)
                            FilledButton(
                              onPressed: onAcceptGroupInvitation,
                              child: const Text('Accept'),
                            ),
                          if (onAcceptGroupInvitation != null &&
                              onDeclineGroupInvitation != null)
                            const SizedBox(width: AppSpacing.xs),
                          if (onDeclineGroupInvitation != null)
                            OutlinedButton(
                              onPressed: onDeclineGroupInvitation,
                              child: const Text('Decline'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _icon(AppNotificationKind kind) => switch (kind) {
  AppNotificationKind.conversationMessage => Icons.chat_bubble_outline_rounded,
  AppNotificationKind.newFollower => Icons.person_add_alt_1_rounded,
  AppNotificationKind.followRequest => Icons.person_search_rounded,
  AppNotificationKind.followRequestAccepted => Icons.verified_outlined,
  AppNotificationKind.messageRequest => Icons.mark_email_unread_outlined,
  AppNotificationKind.messageRequestAccepted => Icons.mark_email_read_outlined,
  AppNotificationKind.groupJoinRequest => Icons.group_add_outlined,
  AppNotificationKind.groupJoinAccepted => Icons.groups_outlined,
  AppNotificationKind.groupInvitation => Icons.mail_outline_rounded,
  AppNotificationKind.groupInvitationAccepted => Icons.mark_email_read_outlined,
  AppNotificationKind.groupAnnouncement => Icons.campaign_outlined,
  AppNotificationKind.groupSessionScheduled => Icons.event_available_outlined,
  AppNotificationKind.groupSessionUpdated => Icons.edit_calendar_outlined,
  AppNotificationKind.groupSessionCancelled => Icons.event_busy_outlined,
  AppNotificationKind.postLike => Icons.favorite_outline_rounded,
  AppNotificationKind.postComment => Icons.mode_comment_outlined,
  AppNotificationKind.postRepost => Icons.repeat_rounded,
  AppNotificationKind.challengeSubmission => Icons.fact_check_outlined,
  AppNotificationKind.challengeReview => Icons.verified_outlined,
  AppNotificationKind.challengeReward => Icons.workspace_premium_outlined,
  AppNotificationKind.challengeReminder => Icons.timer_outlined,
  AppNotificationKind.eventUpdate => Icons.event_outlined,
  AppNotificationKind.marketplaceUpdate => Icons.storefront_outlined,
  AppNotificationKind.systemAlert => Icons.shield_outlined,
  AppNotificationKind.productUpdate => Icons.new_releases_outlined,
  AppNotificationKind.unknown => Icons.notifications_none_rounded,
};

String _relativeTime(DateTime value) {
  final Duration difference = DateTime.now().toUtc().difference(value.toUtc());
  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d';
  }
  final DateTime local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
