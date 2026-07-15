import '../../domain/entities/app_notification.dart';
import '../dto/app_notification_dto.dart';

extension AppNotificationDtoMapper on AppNotificationDto {
  AppNotification toDomain() {
    return AppNotification(
      id: id,
      category: _category(category),
      kind: _kind(kind),
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

AppNotificationKind _kind(String value) => switch (value) {
  'conversation_message' => AppNotificationKind.conversationMessage,
  'new_follower' => AppNotificationKind.newFollower,
  'follow_request' => AppNotificationKind.followRequest,
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
