import 'messaging_user.dart';

enum MessageKind { text, image, video, audio, system, deleted }

enum AttachmentProcessingState { ready, processing, failed }

class MessageAttachment {
  const MessageAttachment({
    required this.id,
    required this.kind,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    required this.processingState,
    this.downloadUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.durationMs,
  });

  final String id;
  final MessageKind kind;
  final String storagePath;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String contentType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final AttachmentProcessingState processingState;
}

class MessageReplyPreview {
  const MessageReplyPreview({
    required this.messageId,
    required this.senderId,
    required this.senderDisplayName,
    required this.kind,
    required this.preview,
  });

  final String messageId;
  final String senderId;
  final String senderDisplayName;
  final MessageKind kind;
  final String preview;
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.kind,
    required this.text,
    required this.attachments,
    required this.reactionCounts,
    required this.viewerReactions,
    required this.sentAt,
    required this.isDeleted,
    this.replyTo,
    this.editedAt,
  });

  final String id;
  final String conversationId;
  final MessagingUser sender;
  final MessageKind kind;
  final String text;
  final List<MessageAttachment> attachments;
  final MessageReplyPreview? replyTo;
  final Map<String, int> reactionCounts;
  final Set<String> viewerReactions;
  final DateTime sentAt;
  final DateTime? editedAt;
  final bool isDeleted;

  String get preview {
    if (isDeleted) {
      return 'Message deleted';
    }
    if (text.trim().isNotEmpty) {
      return text.trim();
    }
    return switch (kind) {
      MessageKind.image => 'Photo',
      MessageKind.video => 'Video',
      MessageKind.audio => 'Audio',
      MessageKind.system => 'Conversation update',
      MessageKind.deleted => 'Message deleted',
      MessageKind.text => 'Message',
    };
  }
}

class MessageCursor {
  const MessageCursor({required this.sentAt, required this.documentId});

  final DateTime sentAt;
  final String documentId;
}

class MessagePage {
  const MessagePage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ConversationMessage> items;
  final bool hasMore;
  final MessageCursor? nextCursor;
}
