enum AppNotificationCategory {
  activity,
  messages,
  events,
  challenges,
  marketplace,
  system,
  productUpdates,
}

enum AppNotificationKind {
  conversationMessage,
  newFollower,
  followRequest,
  postLike,
  postComment,
  postRepost,
  challengeSubmission,
  challengeReview,
  challengeReward,
  challengeReminder,
  eventUpdate,
  marketplaceUpdate,
  systemAlert,
  productUpdate,
  unknown,
}

class NotificationActor {
  const NotificationActor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.kind,
    required this.title,
    required this.body,
    required this.route,
    required this.groupKey,
    required this.groupCount,
    required this.actors,
    required this.data,
    required this.createdAt,
    required this.latestAt,
    required this.updatedAt,
    this.entityType,
    this.entityId,
    this.imageUrl,
    this.readAt,
    this.deletedAt,
  });

  final String id;
  final AppNotificationCategory category;
  final AppNotificationKind kind;
  final String title;
  final String body;
  final String route;
  final String groupKey;
  final int groupCount;
  final List<NotificationActor> actors;
  final Map<String, String> data;
  final String? entityType;
  final String? entityId;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime latestAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final DateTime? deletedAt;

  bool get isUnread => readAt == null && deletedAt == null;

  String get displayBody {
    if (groupCount <= 1) {
      return body;
    }
    final int others = groupCount - 1;
    return '$body · $others more update${others == 1 ? '' : 's'}';
  }
}

class NotificationPage {
  const NotificationPage({required this.items, this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;
}
