import '../../../groups/domain/entities/group_enums.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/messaging_user.dart';
import '../dto/conversation_dto.dart';
import '../dto/message_dto.dart';
import '../dto/messaging_user_dto.dart';

extension MessagingUserDtoMapper on MessagingUserDto {
  MessagingUser toDomain() => MessagingUser(
    id: id,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    isVerified: isVerified,
  );
}

extension ConversationLastMessageDtoMapper on ConversationLastMessageDto {
  ConversationLastMessage toDomain() => ConversationLastMessage(
    id: id,
    senderId: senderId,
    kind: kind,
    preview: preview,
    sentAt: sentAt,
  );
}

extension ConversationSummaryDtoMapper on ConversationSummaryDto {
  ConversationSummary toDomain() => ConversationSummary(
    id: id,
    type: _conversationType(type),
    title: title,
    avatarUrl: avatarUrl,
    members: members.map((MessagingUserDto item) => item.toDomain()).toList(),
    lastMessage: lastMessage?.toDomain(),
    unreadCount: unreadCount,
    isMuted:
        !notificationsEnabled ||
        (mutedUntil != null && mutedUntil!.isAfter(DateTime.now())),
    isArchived: archivedAt != null,
    updatedAt: updatedAt,
    source: source,
    sportsGroupId: sportsGroupId,
    sportsChannelType: sportsChannelType,
  );
}

extension ConversationMemberDtoMapper on ConversationMemberDto {
  ConversationMember toDomain() => ConversationMember(
    user: user.toDomain(),
    role: _memberRole(role),
    joinedAt: joinedAt,
    lastReadAt: lastReadAt,
    mutedUntil: mutedUntil,
    archivedAt: archivedAt,
    notificationsEnabled: notificationsEnabled,
    unreadCount: unreadCount,
  );
}

Conversation conversationToDomain(
  ConversationDto dto,
  List<ConversationMemberDto> members,
) => Conversation(
  id: dto.id,
  type: _conversationType(dto.type),
  title: dto.title,
  avatarUrl: dto.avatarUrl,
  createdBy: dto.createdBy,
  members: members
      .map((ConversationMemberDto item) => item.toDomain())
      .toList(growable: false),
  memberCount: dto.memberCount,
  moderationState: dto.moderationState,
  lastMessage: dto.lastMessage?.toDomain(),
  createdAt: dto.createdAt,
  updatedAt: dto.updatedAt,
  source: dto.source,
  sportsGroupId: dto.sportsGroupId,
  sportsChannelType: dto.sportsChannelType,
);

extension MessageDtoMapper on MessageDto {
  ConversationMessage toDomain({
    Set<String> viewerReactions = const <String>{},
    Set<String> consumedViewOnceAttachmentIds = const <String>{},
  }) => ConversationMessage(
    id: id,
    conversationId: conversationId,
    sender: sender.toDomain(),
    kind: _messageKind(kind),
    text: text,
    attachments: attachments
        .map(
          (MessageAttachmentDto item) => MessageAttachment(
            id: item.id,
            kind: _messageKind(item.kind),
            storagePath: item.storagePath,
            downloadUrl: item.downloadUrl,
            thumbnailUrl: item.thumbnailUrl,
            contentType: item.contentType,
            sizeBytes: item.sizeBytes,
            width: item.width,
            height: item.height,
            durationMs: item.durationMs,
            processingState: _processingState(item.processingState),
            mediaMode: parseGroupMediaMode(item.mediaMode),
            viewOnceConsumed:
                item.viewOnceConsumed ||
                consumedViewOnceAttachmentIds.contains(item.id),
          ),
        )
        .toList(growable: false),
    replyTo: replyTo == null
        ? null
        : MessageReplyPreview(
            messageId: replyTo!.messageId,
            senderId: replyTo!.senderId,
            senderDisplayName: replyTo!.senderDisplayName,
            kind: _messageKind(replyTo!.kind),
            preview: replyTo!.preview,
          ),
    reactionCounts: reactionCounts,
    viewerReactions: viewerReactions,
    sentAt: sentAt,
    editedAt: editedAt,
    isDeleted: isDeleted,
  );
}

ConversationType _conversationType(String value) =>
    value == 'group' ? ConversationType.group : ConversationType.direct;

ConversationMemberRole _memberRole(String value) => switch (value) {
  'owner' => ConversationMemberRole.owner,
  'admin' => ConversationMemberRole.admin,
  _ => ConversationMemberRole.member,
};

MessageKind _messageKind(String value) => switch (value) {
  'image' => MessageKind.image,
  'video' => MessageKind.video,
  'audio' => MessageKind.audio,
  'system' => MessageKind.system,
  'deleted' => MessageKind.deleted,
  _ => MessageKind.text,
};

AttachmentProcessingState _processingState(String value) => switch (value) {
  'processing' => AttachmentProcessingState.processing,
  'failed' => AttachmentProcessingState.failed,
  _ => AttachmentProcessingState.ready,
};
