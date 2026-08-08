import 'group_enums.dart';

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.role,
    required this.displayName,
    required this.username,
    this.joinedAt,
    this.avatarUrl,
  });

  final String userId;
  final GroupMemberRole role;
  final String displayName;
  final String username;
  final DateTime? joinedAt;
  final String? avatarUrl;
}

class GroupJoinRequest {
  const GroupJoinRequest({
    required this.requesterId,
    required this.displayName,
    required this.username,
    this.createdAt,
    this.avatarUrl,
  });

  final String requesterId;
  final String displayName;
  final String username;
  final DateTime? createdAt;
  final String? avatarUrl;
}

/// Outbound pending invitation (manager view for a specific group).
class GroupPendingInvitation {
  const GroupPendingInvitation({
    required this.inviteeId,
    required this.inviterId,
    required this.displayName,
    required this.username,
    this.createdAt,
    this.avatarUrl,
    this.inviterDisplayName,
  });

  final String inviteeId;
  final String inviterId;
  final String displayName;
  final String username;
  final DateTime? createdAt;
  final String? avatarUrl;
  final String? inviterDisplayName;
}
