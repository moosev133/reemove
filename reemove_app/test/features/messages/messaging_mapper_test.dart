import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/messages/data/dto/conversation_dto.dart';
import 'package:reemove/features/messages/data/dto/message_dto.dart';
import 'package:reemove/features/messages/data/dto/messaging_user_dto.dart';
import 'package:reemove/features/messages/data/mappers/messaging_mapper.dart';
import 'package:reemove/features/messages/domain/entities/conversation.dart';
import 'package:reemove/features/messages/domain/entities/message.dart';

void main() {
  const MessagingUserDto user = MessagingUserDto(
    id: 'runner',
    username: 'maya_runner',
    displayName: 'Maya Runner',
    isVerified: true,
  );

  test('maps conversation summaries and muted state', () {
    final ConversationSummary summary = ConversationSummaryDto(
      id: 'conversation-1',
      type: 'group',
      title: 'Weekend Training',
      members: const <MessagingUserDto>[user],
      unreadCount: 3,
      notificationsEnabled: false,
      updatedAt: DateTime.utc(2026, 7, 14),
    ).toDomain();

    expect(summary.type, ConversationType.group);
    expect(summary.isMuted, isTrue);
    expect(summary.unreadCount, 3);
    expect(summary.members.single.isVerified, isTrue);
  });

  test('maps messages, replies, attachments, and viewer reactions', () {
    final ConversationMessage message = MessageDto(
      id: 'message-1',
      conversationId: 'conversation-1',
      sender: user,
      kind: 'image',
      text: 'Finish line',
      attachments: const <MessageAttachmentDto>[
        MessageAttachmentDto(
          id: 'asset-1',
          kind: 'image',
          storagePath: 'messages/conversation-1/message-1/asset-1/photo.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          processingState: 'ready',
        ),
      ],
      reactionCounts: const <String, int>{'🔥': 2},
      sentAt: DateTime.utc(2026, 7, 14),
      isDeleted: false,
    ).toDomain(viewerReactions: const <String>{'🔥'});

    expect(message.kind, MessageKind.image);
    expect(
      message.attachments.single.processingState,
      AttachmentProcessingState.ready,
    );
    expect(message.viewerReactions, contains('🔥'));
    expect(message.preview, 'Finish line');
  });
}
