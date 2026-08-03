import '../../domain/entities/group.dart';
import '../../domain/entities/group_channel.dart';
import '../../domain/entities/group_enums.dart';
import '../../domain/entities/group_invitation.dart';
import '../../domain/entities/group_location.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_membership.dart';
import '../../domain/entities/group_session.dart';
import '../../domain/entities/group_snapshot.dart';

/// Callable responses arrive as loosely-typed maps/lists (platform channel
/// values), so every parser below defensively coerces its input rather than
/// assuming `Map<String, dynamic>` / `List<dynamic>` shapes exactly.
Map<String, dynamic> asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (Object? key, Object? item) => MapEntry(key.toString(), item),
    );
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .map((Object? item) => asStringKeyedMap(item))
      .toList(growable: false);
}

String asString(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

int asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

DateTime? asDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

GroupLocation groupLocationFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  if (map.isEmpty) {
    return GroupLocation.empty;
  }
  return GroupLocation(
    locality: map['locality'] as String?,
    administrativeArea: map['administrativeArea'] as String?,
    countryCode: map['countryCode'] as String?,
    text: map['text'] as String?,
  );
}

GroupSnapshot groupSnapshotFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  return GroupSnapshot(
    name: asString(map['name']),
    privacy: parseGroupPrivacy(map['privacy']),
    category: asString(map['category']),
    memberCount: asInt(map['memberCount']),
    avatarUrl: map['avatarUrl'] as String?,
  );
}

Group groupFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  return Group(
    groupId: asString(map['groupId']),
    name: asString(map['name']),
    description: asString(map['description']),
    category: asString(map['category']),
    privacy: parseGroupPrivacy(map['privacy']),
    joinPolicy: parseGroupJoinPolicy(map['joinPolicy']),
    status: parseGroupStatus(map['status']),
    memberCount: asInt(map['memberCount']),
    capacity: asInt(map['capacity']),
    ownerId: asString(map['ownerId']),
    location: groupLocationFromMap(map['location']),
    membershipStatus: parseGroupMembershipStatus(map['membershipStatus']),
    avatarUrl: map['avatarUrl'] as String?,
    coverUrl: map['coverUrl'] as String?,
    createdAt: asDateTime(map['createdAt']),
    updatedAt: asDateTime(map['updatedAt']),
    viewerRole: tryParseGroupMemberRole(map['viewerRole']),
    memberChatConversationId: map['memberChatConversationId'] as String?,
    announcementsConversationId:
        map['announcementsConversationId'] as String?,
  );
}

GroupMember groupMemberFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  return GroupMember(
    userId: asString(map['userId']),
    role: tryParseGroupMemberRole(map['role']) ?? GroupMemberRole.member,
    displayName: asString(map['displayName']),
    username: asString(map['username']),
    joinedAt: asDateTime(map['joinedAt']),
    avatarUrl: map['avatarUrl'] as String?,
  );
}

GroupJoinRequest groupJoinRequestFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  return GroupJoinRequest(
    requesterId: asString(map['requesterId']),
    displayName: asString(map['displayName']),
    username: asString(map['username']),
    createdAt: asDateTime(map['createdAt']),
    avatarUrl: map['avatarUrl'] as String?,
  );
}

MyGroupMembership myGroupMembershipFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  return MyGroupMembership(
    groupId: asString(map['groupId']),
    role: tryParseGroupMemberRole(map['role']) ?? GroupMemberRole.member,
    snapshot: groupSnapshotFromMap(map['groupSnapshot']),
    joinedAt: asDateTime(map['joinedAt']),
  );
}

GroupInvitation groupInvitationFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  return GroupInvitation(
    groupId: asString(map['groupId']),
    inviterId: asString(map['inviterId']),
    snapshot: groupSnapshotFromMap(map['groupSnapshot']),
    createdAt: asDateTime(map['createdAt']),
  );
}

GroupSession groupSessionFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  return GroupSession(
    sessionId: asString(map['sessionId']),
    title: asString(map['title']),
    activity: asString(map['activity']),
    description: asString(map['description']),
    location: groupLocationFromMap(map['location']),
    capacity: asInt(map['capacity']),
    status: parseGroupSessionStatus(map['status']),
    startAt: asDateTime(map['startAt']),
    endAt: asDateTime(map['endAt']),
    createdBy: map['createdBy'] as String?,
  );
}

GroupChannel groupChannelFromMap(Object? value) {
  final Map<String, dynamic> map = asStringKeyedMap(value);
  final List<Object?> modes = (map['supportedMediaModes'] as List?) ?? const [];
  final List<Object?> publish = (map['publishRoles'] as List?) ?? const [];
  final List<Object?> read = (map['readRoles'] as List?) ?? const [];
  return GroupChannel(
    channelId: asString(map['channelId']),
    type: parseGroupChannelType(map['type']),
    conversationId: asString(map['conversationId']),
    supportedMediaModes: modes
        .map((Object? item) => parseGroupMediaMode(item))
        .toList(growable: false),
    publishRoles: publish
        .map((Object? item) => tryParseGroupMemberRole(item))
        .whereType<GroupMemberRole>()
        .toList(growable: false),
    readRoles: read
        .map((Object? item) => tryParseGroupMemberRole(item))
        .whereType<GroupMemberRole>()
        .toList(growable: false),
    normalMediaSupported: map['normalMediaSupported'] as bool? ?? true,
    keepInChatSupported: map['keepInChatSupported'] as bool? ?? true,
    // Always false in C1; see GroupChannel doc comment.
    viewOnceSupported: false,
  );
}
