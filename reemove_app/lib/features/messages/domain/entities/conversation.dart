import '../../../groups/domain/entities/sports_group_channel_context.dart';
import 'messaging_user.dart';

enum ConversationType { direct, group }

enum ConversationMemberRole { owner, admin, member }

class ConversationLastMessage {
  const ConversationLastMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.preview,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String kind;
  final String preview;
  final DateTime sentAt;
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.members,
    required this.unreadCount,
    required this.isMuted,
    required this.isArchived,
    required this.updatedAt,
    this.avatarUrl,
    this.lastMessage,
    this.source,
    this.sportsGroupId,
    this.sportsChannelType,
  });

  final String id;
  final ConversationType type;
  final String title;
  final String? avatarUrl;
  final List<MessagingUser> members;
  final ConversationLastMessage? lastMessage;
  final int unreadCount;
  final bool isMuted;
  final bool isArchived;
  final DateTime updatedAt;
  final String? source;
  final String? sportsGroupId;
  final String? sportsChannelType;

  bool get isSportsGroupChannel =>
      source == SportsGroupChannelContext.sourceValue &&
      sportsGroupId != null &&
      sportsGroupId!.isNotEmpty;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    required this.createdBy,
    required this.members,
    required this.memberCount,
    required this.moderationState,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.lastMessage,
    this.source,
    this.sportsGroupId,
    this.sportsChannelType,
  });

  final String id;
  final ConversationType type;
  final String title;
  final String? avatarUrl;
  final String createdBy;
  final List<ConversationMember> members;
  final int memberCount;
  final String moderationState;
  final ConversationLastMessage? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? source;
  final String? sportsGroupId;
  final String? sportsChannelType;

  bool get isGroup => type == ConversationType.group;

  bool get isSportsGroupChannel =>
      source == SportsGroupChannelContext.sourceValue &&
      sportsGroupId != null &&
      sportsGroupId!.isNotEmpty;

  ConversationMember? member(String uid) {
    for (final ConversationMember item in members) {
      if (item.user.id == uid) {
        return item;
      }
    }
    return null;
  }
}

class ConversationMember {
  const ConversationMember({
    required this.user,
    required this.role,
    required this.joinedAt,
    required this.notificationsEnabled,
    required this.unreadCount,
    this.lastReadAt,
    this.mutedUntil,
    this.archivedAt,
  });

  final MessagingUser user;
  final ConversationMemberRole role;
  final DateTime joinedAt;
  final DateTime? lastReadAt;
  final DateTime? mutedUntil;
  final DateTime? archivedAt;
  final bool notificationsEnabled;
  final int unreadCount;

  bool get isAdmin =>
      role == ConversationMemberRole.owner ||
      role == ConversationMemberRole.admin;
}
