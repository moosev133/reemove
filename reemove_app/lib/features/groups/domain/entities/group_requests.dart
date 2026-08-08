import 'group_enums.dart';
import 'group_location.dart';

class CreateGroupRequest {
  const CreateGroupRequest({
    required this.name,
    required this.description,
    required this.category,
    required this.privacy,
    required this.joinPolicy,
    required this.capacity,
    this.location = GroupLocation.empty,
    this.avatarUrl,
    this.coverUrl,
  });

  final String name;
  final String description;
  final String category;
  final GroupPrivacy privacy;
  final GroupJoinPolicy joinPolicy;
  final int capacity;
  final GroupLocation location;
  final String? avatarUrl;
  final String? coverUrl;
}

/// A patch for `updateGroup`. Only non-null fields are sent, matching the
/// callable's partial-update contract.
class UpdateGroupRequest {
  const UpdateGroupRequest({
    required this.groupId,
    this.name,
    this.description,
    this.category,
    this.privacy,
    this.joinPolicy,
    this.location,
    this.capacity,
    this.avatarUrl,
    this.coverUrl,
    this.status,
  });

  final String groupId;
  final String? name;
  final String? description;
  final String? category;
  final GroupPrivacy? privacy;
  final GroupJoinPolicy? joinPolicy;
  final GroupLocation? location;
  final int? capacity;
  final String? avatarUrl;
  final String? coverUrl;
  final GroupStatus? status;
}

class CreateGroupSessionRequest {
  const CreateGroupSessionRequest({
    required this.groupId,
    required this.title,
    required this.sessionType,
    required this.startAt,
    required this.endAt,
    this.activity = '',
    this.description = '',
    this.capacity = 0,
    this.location = GroupLocation.empty,
  });

  final String groupId;
  final String title;
  final GroupSessionType sessionType;
  final String activity;
  final DateTime startAt;
  final DateTime endAt;
  final String description;
  final int capacity;
  final GroupLocation location;
}

class UpdateGroupSessionRequest {
  const UpdateGroupSessionRequest({
    required this.groupId,
    required this.sessionId,
    this.title,
    this.sessionType,
    this.activity,
    this.description,
    this.startAt,
    this.endAt,
    this.capacity,
    this.location,
  });

  final String groupId;
  final String sessionId;
  final String? title;
  final GroupSessionType? sessionType;
  final String? activity;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final int? capacity;
  final GroupLocation? location;
}

/// Outcome of `requestJoinGroup`: either immediate membership (open groups)
/// or a pending request awaiting manager approval.
enum GroupJoinOutcome { joinedAsMember, pending }
