import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/messages/domain/entities/message.dart';
import 'package:reemove/features/messages/domain/entities/messaging_user.dart';
import 'package:reemove/features/messages/presentation/conversation_message_action_policy.dart';

ConversationMessage _message({required String senderId, bool deleted = false}) {
  return ConversationMessage(
    id: 'm1',
    conversationId: 'c1',
    sender: MessagingUser(
      id: senderId,
      displayName: 'User',
      username: 'user',
      isVerified: false,
    ),
    kind: deleted ? MessageKind.deleted : MessageKind.text,
    text: deleted ? '' : 'hello',
    attachments: const <MessageAttachment>[],
    reactionCounts: const <String, int>{},
    viewerReactions: const <String>{},
    sentAt: DateTime.utc(2026, 1, 1),
    isDeleted: deleted,
  );
}

void main() {
  group('ConversationMessageActionPolicy', () {
    test('owner sees moderator delete on peer messages', () {
      expect(
        ConversationMessageActionPolicy.showModeratorDelete(
          isMine: false,
          message: _message(senderId: 'peer'),
          canModerate: true,
        ),
        isTrue,
      );
      expect(
        ConversationMessageActionPolicy.showDeleteOwn(
          isMine: false,
          message: _message(senderId: 'peer'),
        ),
        isFalse,
      );
      expect(
        ConversationMessageActionPolicy.showReport(
          isMine: false,
          canModerate: true,
        ),
        isFalse,
      );
    });

    test('admin sees moderator delete on peer messages', () {
      expect(
        ConversationMessageActionPolicy.showModeratorDelete(
          isMine: false,
          message: _message(senderId: 'peer'),
          canModerate: true,
        ),
        isTrue,
      );
    });

    test('normal member only deletes own messages and reports others', () {
      expect(
        ConversationMessageActionPolicy.showDeleteOwn(
          isMine: true,
          message: _message(senderId: 'self'),
        ),
        isTrue,
      );
      expect(
        ConversationMessageActionPolicy.showModeratorDelete(
          isMine: false,
          message: _message(senderId: 'owner'),
          canModerate: false,
        ),
        isFalse,
      );
      expect(
        ConversationMessageActionPolicy.showReport(
          isMine: false,
          canModerate: false,
        ),
        isTrue,
      );
    });

    test('deleted messages hide delete actions', () {
      final ConversationMessage deleted = _message(
        senderId: 'self',
        deleted: true,
      );
      expect(
        ConversationMessageActionPolicy.showDeleteOwn(
          isMine: true,
          message: deleted,
        ),
        isFalse,
      );
      expect(
        ConversationMessageActionPolicy.showModeratorDelete(
          isMine: false,
          message: deleted,
          canModerate: true,
        ),
        isFalse,
      );
    });
  });
}

