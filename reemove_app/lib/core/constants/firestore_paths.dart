abstract final class FirestoreCollections {
  static const String users = 'users';
  static const String usernames = 'usernames';
  static const String sports = 'sports';
  static const String posts = 'posts';
  static const String stories = 'stories';
  static const String conversations = 'conversations';
  static const String messageReports = 'message_reports';
  static const String notificationDeliveries = 'notification_deliveries';
  static const String groups = 'groups';
  static const String places = 'places';
  static const String teams = 'teams';
  static const String events = 'events';
  static const String routes = 'routes';
  static const String activities = 'activities';
  static const String challenges = 'challenges';
  static const String leaderboards = 'leaderboards';
  static const String badges = 'badges';
  static const String rewards = 'rewards';
  static const String trainerProfiles = 'trainer_profiles';
  static const String trainerServices = 'trainer_services';
  static const String marketplaceListings = 'marketplace_listings';
  static const String reports = 'reports';
  static const String verificationRequests = 'verification_requests';
  static const String moderationQueue = 'moderation_queue';
  static const String aiRequests = 'ai_requests';
  static const String aiArtifacts = 'ai_artifacts';
  static const String feedEntries = 'feed_entries';
  static const String contentReactions = 'content_reactions';
  static const String reposts = 'reposts';
  static const String commentReactions = 'comment_reactions';
  static const String storyViews = 'story_views';
  static const String mediaAssets = 'media_assets';
  static const String mediaJobs = 'media_jobs';
  static const String searchDocuments = 'search_documents';
  static const String appConfig = 'app_config';
  static const String featureFlags = 'feature_flags';
  static const String auditLogs = 'audit_logs';
  static const String dataMigrations = 'data_migrations';
  static const String accountDeletions = 'account_deletions';
  static const String rateLimits = 'rate_limits';

  /// User subcollections (path segment after `/users/{uid}/`).
  static const String conversationInbox = 'conversation_inbox';
  static const String messageReactions = 'message_reactions';
  static const String followRequests = 'follow_requests';
  static const String members = 'members';
  static const String messages = 'messages';
}

/// Canonical Firestore path helpers for shared document locations.
abstract final class FirestorePaths {
  static String user(String uid) => '${FirestoreCollections.users}/$uid';

  static String userConversationInbox(String uid) =>
      '${user(uid)}/${FirestoreCollections.conversationInbox}';

  static String userMessageReactions(String uid) =>
      '${user(uid)}/${FirestoreCollections.messageReactions}';

  static String conversation(String conversationId) =>
      '${FirestoreCollections.conversations}/$conversationId';

  static String conversationMembers(String conversationId) =>
      '${conversation(conversationId)}/${FirestoreCollections.members}';

  static String conversationMessages(String conversationId) =>
      '${conversation(conversationId)}/${FirestoreCollections.messages}';
}
