import '../../../../core/result/result.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';
import '../entities/messaging_action.dart';

abstract interface class MessagingRepository {
  Stream<Result<List<ConversationSummary>>> watchInbox({
    required String userId,
    bool archived = false,
    int limit = 50,
  });

  Stream<Result<int>> watchUnreadCount(String userId);

  Stream<Result<Conversation?>> watchConversation({
    required String conversationId,
    required String viewerId,
  });

  Stream<Result<List<ConversationMessage>>> watchRecentMessages({
    required String conversationId,
    required String viewerId,
    int limit = 40,
  });

  Future<Result<MessagePage>> loadOlderMessages({
    required String conversationId,
    required String viewerId,
    required MessageCursor cursor,
    int limit = 40,
  });

  Future<Result<String>> createDirectConversation(String targetUserId);

  /// Creates a message request, or opens a direct conversation when allowed.
  ///
  /// Returns a conversation id when a chat is opened immediately; otherwise
  /// null when a pending request was created or already existed.
  Future<Result<String?>> createMessageRequest(String targetUserId);

  Future<Result<void>> cancelMessageRequest(String targetUserId);

  /// Accepts or declines a message request.
  ///
  /// On accept, returns the opened conversation id. On decline, returns null.
  Future<Result<String?>> respondToMessageRequest({
    required String requesterId,
    required String decision,
  });

  Future<Result<String>> createGroupConversation({
    required String title,
    required List<String> memberIds,
  });

  Future<Result<void>> updateGroup({
    required String conversationId,
    String? title,
    String? avatarUrl,
    String? avatarStoragePath,
    List<String> addMemberIds = const <String>[],
    List<String> removeMemberIds = const <String>[],
  });

  Future<Result<void>> leaveConversation(String conversationId);

  Future<Result<ConversationMessage>> sendMessage(SendMessageRequest request);

  Future<Result<void>> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  });

  Future<Result<void>> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  Future<Result<void>> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  });

  Future<Result<void>> markRead({
    required String conversationId,
    required String messageId,
    required DateTime messageSentAt,
  });

  Future<Result<void>> updatePreferences(ConversationPreferencesUpdate update);

  Future<Result<void>> reportMessage({
    required String conversationId,
    required String messageId,
    required String reason,
    String details = '',
  });
}
