import '../../../../core/result/result.dart';
import '../entities/group.dart';
import '../entities/group_channel.dart';
import '../entities/group_enums.dart';
import '../entities/group_invitation.dart';
import '../entities/group_member.dart';
import '../entities/group_membership.dart';
import '../entities/group_requests.dart';
import '../entities/group_session.dart';

abstract class GroupsRepository {
  Future<Result<String>> createGroup(CreateGroupRequest request);
  Future<Result<void>> updateGroup(UpdateGroupRequest request);
  Future<Result<Group>> getGroup(String groupId);
  Future<Result<List<Group>>> listDiscoverableGroups({
    String? category,
    int limit = 20,
  });
  Future<Result<List<MyGroupMembership>>> listMyGroups({int limit = 40});
  Future<Result<GroupJoinOutcome>> requestJoinGroup(String groupId);
  Future<Result<void>> cancelJoinRequest(String groupId);
  Future<Result<void>> respondToJoinRequest({
    required String groupId,
    required String requesterId,
    required bool approve,
  });
  Future<Result<bool>> inviteToGroup({
    required String groupId,
    required String inviteeId,
  });
  Future<Result<void>> respondToGroupInvitation({
    required String groupId,
    required bool accept,
  });
  Future<Result<void>> cancelGroupInvitation({
    required String groupId,
    required String inviteeId,
  });
  Future<Result<void>> removeGroupMember({
    required String groupId,
    required String memberId,
  });
  Future<Result<void>> setGroupMemberRole({
    required String groupId,
    required String memberId,
    required GroupMemberRole role,
  });
  Future<Result<void>> transferGroupOwnership({
    required String groupId,
    required String newOwnerId,
  });
  Future<Result<void>> leaveGroup(String groupId);
  Future<Result<void>> deleteGroup(String groupId);
  Future<Result<List<GroupMember>>> listGroupMembers(String groupId);
  Future<Result<List<GroupJoinRequest>>> listGroupJoinRequests(String groupId);
  Future<Result<List<GroupPendingInvitation>>> listGroupPendingInvitations(
    String groupId,
  );
  Future<Result<List<GroupInvitation>>> listMyGroupInvitations();
  Future<Result<String>> createGroupSession(CreateGroupSessionRequest request);
  Future<Result<void>> updateGroupSession(UpdateGroupSessionRequest request);
  Future<Result<void>> cancelGroupSession({
    required String groupId,
    required String sessionId,
  });
  Future<Result<List<GroupSession>>> listGroupSessions(String groupId);
  Future<Result<void>> respondToGroupSessionRsvp({
    required String groupId,
    required String sessionId,
    required GroupSessionRsvpStatus status,
  });
  Future<Result<List<GroupChannel>>> getGroupChannels(String groupId);
  Future<Result<String>> reportGroup({
    required String groupId,
    required String reason,
    String? details,
  });
}
