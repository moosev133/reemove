import 'group_enums.dart';
import 'group_location.dart';

class Group {
  const Group({
    required this.groupId,
    required this.name,
    required this.description,
    required this.category,
    required this.privacy,
    required this.joinPolicy,
    required this.status,
    required this.memberCount,
    required this.capacity,
    required this.ownerId,
    required this.location,
    required this.membershipStatus,
    this.avatarUrl,
    this.coverUrl,
    this.createdAt,
    this.updatedAt,
    this.viewerRole,
    this.memberChatConversationId,
    this.announcementsConversationId,
  });

  final String groupId;
  final String name;
  final String description;
  final String category;
  final GroupPrivacy privacy;
  final GroupJoinPolicy joinPolicy;
  final GroupStatus status;
  final int memberCount;
  final int capacity;
  final String ownerId;
  final GroupLocation location;
  final String? avatarUrl;
  final String? coverUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GroupMemberRole? viewerRole;
  final GroupMembershipStatus membershipStatus;
  final String? memberChatConversationId;
  final String? announcementsConversationId;

  bool get isFull => capacity > 0 && memberCount >= capacity;

  bool get isMember => viewerRole != null;

  bool get isManager =>
      viewerRole == GroupMemberRole.owner ||
      viewerRole == GroupMemberRole.admin ||
      membershipStatus == GroupMembershipStatus.owner ||
      membershipStatus == GroupMembershipStatus.admin;

  bool get isOwner =>
      viewerRole == GroupMemberRole.owner ||
      membershipStatus == GroupMembershipStatus.owner;

  /// Owner/admin moderation for the authenticated viewer of this snapshot.
  bool canModerateAs(String? viewerUid) {
    if (viewerUid == null || viewerUid.isEmpty) {
      return false;
    }
    if (viewerUid == ownerId) {
      return true;
    }
    return isManager;
  }

  bool get hasPendingRequest =>
      membershipStatus == GroupMembershipStatus.pending;
}
