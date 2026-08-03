enum FollowRelationshipState {
  self,
  none,
  following,
  followedBy,
  mutual,
  requestSent,
  requestReceived,
  blocked,
  blockedBy,
}

class ProfileRelationship {
  const ProfileRelationship({
    required this.viewerId,
    required this.profileId,
    required this.state,
    required this.canMessage,
    required this.canViewFollowers,
    this.canRequestMessage = false,
    this.messageRequestStatus,
    this.canViewProfile = true,
    this.requestedAt,
  });

  final String viewerId;
  final String profileId;
  final FollowRelationshipState state;
  final bool canMessage;
  final bool canRequestMessage;
  final String? messageRequestStatus;
  final bool canViewFollowers;
  final bool canViewProfile;
  final DateTime? requestedAt;

  bool get hasPendingMessageRequest => messageRequestStatus == 'pending';

  bool get isFollowing =>
      state == FollowRelationshipState.following ||
      state == FollowRelationshipState.mutual;

  bool get followsViewer =>
      state == FollowRelationshipState.followedBy ||
      state == FollowRelationshipState.mutual;

  bool get hasPendingRequest =>
      state == FollowRelationshipState.requestSent ||
      state == FollowRelationshipState.requestReceived;

  bool get isBlocked =>
      state == FollowRelationshipState.blocked ||
      state == FollowRelationshipState.blockedBy;
}
