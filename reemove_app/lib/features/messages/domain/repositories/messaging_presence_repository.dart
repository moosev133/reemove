import '../../../../core/result/result.dart';
import '../entities/messaging_presence.dart';

abstract interface class MessagingPresenceRepository {
  Future<Result<void>> joinConversation({
    required String conversationId,
    required String userId,
  });

  Future<Result<void>> leaveConversation({
    required String conversationId,
    required String userId,
  });

  Stream<Result<Map<String, MessagingPresence>>> watchPresence(
    String conversationId,
  );

  Stream<Result<List<TypingParticipant>>> watchTyping(String conversationId);

  Future<Result<void>> setTyping({
    required String conversationId,
    required String userId,
    required bool isTyping,
  });
}
