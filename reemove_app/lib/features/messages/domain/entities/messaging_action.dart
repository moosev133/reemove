import 'message_attachment_draft.dart';

class SendMessageRequest {
  const SendMessageRequest({
    required this.conversationId,
    required this.clientMessageId,
    required this.text,
    required this.attachments,
    this.replyToMessageId,
  });

  final String conversationId;
  final String clientMessageId;
  final String text;
  final List<UploadedMessageAttachment> attachments;
  final String? replyToMessageId;
}

class ConversationPreferencesUpdate {
  const ConversationPreferencesUpdate({
    required this.conversationId,
    this.mutedUntil,
    this.notificationsEnabled,
    this.archived,
  });

  final String conversationId;
  final DateTime? mutedUntil;
  final bool? notificationsEnabled;
  final bool? archived;
}
