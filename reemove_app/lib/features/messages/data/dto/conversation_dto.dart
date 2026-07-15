import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';
import 'messaging_user_dto.dart';

class ConversationLastMessageDto {
  const ConversationLastMessageDto({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.preview,
    required this.sentAt,
  });

  factory ConversationLastMessageDto.fromMap(FirestoreMap data) =>
      ConversationLastMessageDto(
        id: FirestoreParser.string(data, 'id'),
        senderId: FirestoreParser.string(data, 'senderId'),
        kind: FirestoreParser.string(data, 'kind', fallback: 'text'),
        preview: FirestoreParser.string(data, 'preview', fallback: ''),
        sentAt: FirestoreParser.dateTime(data, 'sentAt'),
      );

  final String id;
  final String senderId;
  final String kind;
  final String preview;
  final DateTime sentAt;
}

class ConversationSummaryDto {
  const ConversationSummaryDto({
    required this.id,
    required this.type,
    required this.title,
    required this.members,
    required this.unreadCount,
    required this.notificationsEnabled,
    required this.updatedAt,
    this.avatarUrl,
    this.lastMessage,
    this.mutedUntil,
    this.archivedAt,
  });

  factory ConversationSummaryDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap data = snapshot.data() ?? const <String, dynamic>{};
    final FirestoreMap? last = data['lastMessage'] is Map
        ? (data['lastMessage'] as Map).cast<String, dynamic>()
        : null;
    return ConversationSummaryDto(
      id: snapshot.id,
      type: FirestoreParser.string(data, 'type', fallback: 'direct'),
      title: FirestoreParser.string(data, 'title', fallback: 'Conversation'),
      avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      members: FirestoreParser.mapList(
        data,
        'memberSnapshots',
      ).map(MessagingUserDto.fromMap).toList(growable: false),
      lastMessage: last == null
          ? null
          : ConversationLastMessageDto.fromMap(last),
      unreadCount: FirestoreParser.integer(data, 'unreadCount', fallback: 0),
      mutedUntil: FirestoreParser.nullableDateTime(data, 'mutedUntil'),
      archivedAt: FirestoreParser.nullableDateTime(data, 'archivedAt'),
      notificationsEnabled: FirestoreParser.boolean(
        data,
        'notificationsEnabled',
        fallback: true,
      ),
      updatedAt: FirestoreParser.dateTime(data, 'updatedAt'),
    );
  }

  final String id;
  final String type;
  final String title;
  final String? avatarUrl;
  final List<MessagingUserDto> members;
  final ConversationLastMessageDto? lastMessage;
  final int unreadCount;
  final DateTime? mutedUntil;
  final DateTime? archivedAt;
  final bool notificationsEnabled;
  final DateTime updatedAt;
}

class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.createdBy,
    required this.memberCount,
    required this.moderationState,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.lastMessage,
  });

  factory ConversationDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap data = snapshot.data() ?? const <String, dynamic>{};
    final FirestoreMap? last = data['lastMessage'] is Map
        ? (data['lastMessage'] as Map).cast<String, dynamic>()
        : null;
    return ConversationDto(
      id: snapshot.id,
      type: FirestoreParser.string(data, 'type', fallback: 'direct'),
      title: FirestoreParser.string(data, 'title', fallback: 'Conversation'),
      avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      createdBy: FirestoreParser.string(data, 'createdBy'),
      memberCount: FirestoreParser.integer(data, 'memberCount', fallback: 0),
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      lastMessage: last == null
          ? null
          : ConversationLastMessageDto.fromMap(last),
      createdAt: FirestoreParser.dateTime(data, 'createdAt'),
      updatedAt: FirestoreParser.dateTime(data, 'updatedAt'),
    );
  }

  final String id;
  final String type;
  final String title;
  final String? avatarUrl;
  final String createdBy;
  final int memberCount;
  final String moderationState;
  final ConversationLastMessageDto? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ConversationMemberDto {
  const ConversationMemberDto({
    required this.user,
    required this.role,
    required this.joinedAt,
    required this.notificationsEnabled,
    required this.unreadCount,
    this.lastReadAt,
    this.mutedUntil,
    this.archivedAt,
  });

  factory ConversationMemberDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap data = snapshot.data() ?? const <String, dynamic>{};
    return ConversationMemberDto(
      user: MessagingUserDto.fromMap(FirestoreParser.map(data, 'userSnapshot')),
      role: FirestoreParser.string(data, 'role', fallback: 'member'),
      joinedAt: FirestoreParser.dateTime(data, 'joinedAt'),
      lastReadAt: FirestoreParser.nullableDateTime(data, 'lastReadAt'),
      mutedUntil: FirestoreParser.nullableDateTime(data, 'mutedUntil'),
      archivedAt: FirestoreParser.nullableDateTime(data, 'archivedAt'),
      notificationsEnabled: FirestoreParser.boolean(
        data,
        'notificationsEnabled',
        fallback: true,
      ),
      unreadCount: FirestoreParser.integer(data, 'unreadCount', fallback: 0),
    );
  }

  final MessagingUserDto user;
  final String role;
  final DateTime joinedAt;
  final DateTime? lastReadAt;
  final DateTime? mutedUntil;
  final DateTime? archivedAt;
  final bool notificationsEnabled;
  final int unreadCount;
}
