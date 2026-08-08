import '../domain/entities/message.dart';

/// Visibility rules for the conversation message action sheet.
abstract final class ConversationMessageActionPolicy {
  static bool showEdit({
    required bool isMine,
    required ConversationMessage message,
  }) =>
      isMine && !message.isDeleted && message.text.isNotEmpty;

  static bool showDeleteOwn({
    required bool isMine,
    required ConversationMessage message,
  }) =>
      isMine && !message.isDeleted;

  /// Owner/admin moderation delete for sports group channels.
  static bool showModeratorDelete({
    required bool isMine,
    required ConversationMessage message,
    required bool canModerate,
  }) =>
      canModerate && !isMine && !message.isDeleted;

  static bool showReport({
    required bool isMine,
    required bool canModerate,
  }) =>
      !isMine && !canModerate;
}

