import '../../domain/entities/app_notification.dart';
import '../dto/app_notification_dto.dart';

extension AppNotificationDtoMapper on AppNotificationDto {
  AppNotification toDomain() {
    final AppNotificationKind mappedKind = _kind(this);
    return AppNotification(
      id: id,
      category: _category(category),
      kind: mappedKind,
      title: title,
      body: body,
      route: route,
      groupKey: groupKey,
      groupCount: groupCount,
      actors: actors
          .map(
            (NotificationActorDto actor) => NotificationActor(
              id: actor.id,
              username: actor.username,
              displayName: actor.displayName,
              avatarUrl: actor.avatarUrl,
              isVerified: actor.isVerified,
            ),
          )
          .toList(growable: false),
      data: data,
      entityType: entityType,
      entityId: entityId,
      imageUrl: imageUrl,
      createdAt: createdAt,
      latestAt: latestAt,
      updatedAt: updatedAt,
      readAt: readAt,
      deletedAt: deletedAt,
    );
  }
}

AppNotificationCategory _category(String value) => switch (value) {
  'messages' => AppNotificationCategory.messages,
  'events' => AppNotificationCategory.events,
  'challenges' => AppNotificationCategory.challenges,
  'marketplace' => AppNotificationCategory.marketplace,
  'system' => AppNotificationCategory.system,
  'productUpdates' => AppNotificationCategory.productUpdates,
  _ => AppNotificationCategory.activity,
};

AppNotificationKind _kind(AppNotificationDto notification) {
  final String value = notification.kind;
  if (value == 'new_follower') {
    final String? relationshipStatus = notification.data['relationshipStatus'];
    final String? source = notification.data['source'];
    final String? status = notification.data['status'];
    final bool confirmed =
        relationshipStatus == 'confirmed' &&
        source == 'direct_follow' &&
        status != 'resolved' &&
        status != 'orphaned';
    if (!confirmed) {
      return AppNotificationKind.unknown;
    }
    return AppNotificationKind.newFollower;
  }
  if (value == 'follow_request') {
    final String? status = notification.data['status'];
    if (status == 'resolved' || status == 'accepted' || status == 'declined') {
      return AppNotificationKind.unknown;
    }
    return AppNotificationKind.followRequest;
  }
  if (value == 'message_request') {
    final String? status = notification.data['status'];
    if (status == 'resolved' || status == 'accepted' || status == 'declined') {
      return AppNotificationKind.unknown;
    }
    return AppNotificationKind.messageRequest;
  }
  return switch (value) {
    'conversation_message' => AppNotificationKind.conversationMessage,
    'follow_request_accepted' => AppNotificationKind.followRequestAccepted,
    'message_request_accepted' => AppNotificationKind.messageRequestAccepted,
    'group_join_request' => AppNotificationKind.groupJoinRequest,
    'group_join_accepted' => AppNotificationKind.groupJoinAccepted,
    'group_invitation' => AppNotificationKind.groupInvitation,
    'group_invitation_accepted' => AppNotificationKind.groupInvitationAccepted,
    'group_announcement' => AppNotificationKind.groupAnnouncement,
    'group_session_scheduled' => AppNotificationKind.groupSessionScheduled,
    'group_session_updated' => AppNotificationKind.groupSessionUpdated,
    'group_session_cancelled' => AppNotificationKind.groupSessionCancelled,
    'post_like' => AppNotificationKind.postLike,
    'post_comment' => AppNotificationKind.postComment,
    'post_repost' => AppNotificationKind.postRepost,
    'challenge_submission' => AppNotificationKind.challengeSubmission,
    'challenge_review' => AppNotificationKind.challengeReview,
    'challenge_reward' => AppNotificationKind.challengeReward,
    'challenge_reminder' => AppNotificationKind.challengeReminder,
    'event_update' => AppNotificationKind.eventUpdate,
    'marketplace_update' => AppNotificationKind.marketplaceUpdate,
    'system_alert' => AppNotificationKind.systemAlert,
    'product_update' => AppNotificationKind.productUpdate,
    _ => AppNotificationKind.unknown,
  };
}
