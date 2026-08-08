import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/result/result.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_channel.dart';
import '../../domain/entities/group_enums.dart';
import '../../domain/entities/group_invitation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_membership.dart';
import '../../domain/entities/group_requests.dart';
import '../../domain/entities/group_session.dart';
import '../../domain/repositories/groups_repository.dart';
import '../mappers/group_response_mapper.dart';
import '../services/groups_failure_mapper.dart';

class FirebaseGroupsRepository implements GroupsRepository {
  const FirebaseGroupsRepository({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<Result<String>> createGroup(CreateGroupRequest request) async {
    try {
      final Map<String, dynamic> response =
          await _call('createGroup', <String, Object?>{
            'name': request.name,
            'description': request.description,
            'category': request.category,
            'privacy': request.privacy.name,
            'joinPolicy': request.joinPolicy.name,
            'capacity': request.capacity,
            if (!request.location.isEmpty) 'location': request.location.toMap(),
            if (request.avatarUrl != null) 'avatarUrl': request.avatarUrl,
            if (request.coverUrl != null) 'coverUrl': request.coverUrl,
          });
      return Success<String>(_requiredString(response, 'groupId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(GroupsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<String>(GroupsFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> updateGroup(UpdateGroupRequest request) =>
      _voidCall('updateGroup', <String, Object?>{
        'groupId': request.groupId,
        if (request.name != null) 'name': request.name,
        if (request.description != null) 'description': request.description,
        if (request.category != null) 'category': request.category,
        if (request.privacy != null) 'privacy': request.privacy!.name,
        if (request.joinPolicy != null) 'joinPolicy': request.joinPolicy!.name,
        if (request.location != null) 'location': request.location!.toMap(),
        if (request.capacity != null) 'capacity': request.capacity,
        if (request.avatarUrl != null) 'avatarUrl': request.avatarUrl,
        if (request.coverUrl != null) 'coverUrl': request.coverUrl,
        if (request.status != null) 'status': request.status!.name,
      });

  @override
  Future<Result<Group>> getGroup(String groupId) async {
    try {
      final Map<String, dynamic> response = await _call(
        'getGroup',
        <String, Object?>{'groupId': groupId},
      );
      return Success<Group>(groupFromMap(response['group']));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<Group>(GroupsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<Group>(GroupsFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<List<Group>>> listDiscoverableGroups({
    String? category,
    int limit = 20,
  }) async {
    try {
      final Map<String, dynamic> response =
          await _call('listDiscoverableGroups', <String, Object?>{
            'limit': limit,
            if (category != null && category.isNotEmpty) 'category': category,
          });
      return Success<List<Group>>(
        asMapList(response['groups'])
            .map((Map<String, dynamic> item) => groupFromMap(item))
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<Group>>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<List<Group>>(GroupsFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<List<MyGroupMembership>>> listMyGroups({int limit = 40}) async {
    try {
      final Map<String, dynamic> response = await _call(
        'listMyGroups',
        <String, Object?>{'limit': limit},
      );
      return Success<List<MyGroupMembership>>(
        asMapList(response['groups'])
            .map((Map<String, dynamic> item) => myGroupMembershipFromMap(item))
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<MyGroupMembership>>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<List<MyGroupMembership>>(
        GroupsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<GroupJoinOutcome>> requestJoinGroup(String groupId) async {
    try {
      final Map<String, dynamic> response = await _call(
        'requestJoinGroup',
        <String, Object?>{'groupId': groupId},
      );
      final String status = _requiredString(response, 'status');
      return Success<GroupJoinOutcome>(
        status == 'pending'
            ? GroupJoinOutcome.pending
            : GroupJoinOutcome.joinedAsMember,
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<GroupJoinOutcome>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<GroupJoinOutcome>(
        GroupsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> cancelJoinRequest(String groupId) =>
      _voidCall('cancelJoinRequest', <String, Object?>{'groupId': groupId});

  @override
  Future<Result<void>> respondToJoinRequest({
    required String groupId,
    required String requesterId,
    required bool approve,
  }) => _voidCall('respondToJoinRequest', <String, Object?>{
    'groupId': groupId,
    'requesterId': requesterId,
    'decision': approve ? 'accept' : 'decline',
  });

  @override
  Future<Result<bool>> inviteToGroup({
    required String groupId,
    required String inviteeId,
  }) async {
    try {
      final Map<String, dynamic> response = await _call(
        'inviteToGroup',
        <String, Object?>{'groupId': groupId, 'inviteeId': inviteeId},
      );
      return Success<bool>(response['created'] as bool? ?? false);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<bool>(GroupsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<bool>(GroupsFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> respondToGroupInvitation({
    required String groupId,
    required bool accept,
  }) => _voidCall('respondToGroupInvitation', <String, Object?>{
    'groupId': groupId,
    'decision': accept ? 'accept' : 'decline',
  });

  @override
  Future<Result<void>> cancelGroupInvitation({
    required String groupId,
    required String inviteeId,
  }) => _voidCall('cancelGroupInvitation', <String, Object?>{
    'groupId': groupId,
    'inviteeId': inviteeId,
  });

  @override
  Future<Result<void>> removeGroupMember({
    required String groupId,
    required String memberId,
  }) => _voidCall('removeGroupMember', <String, Object?>{
    'groupId': groupId,
    'memberId': memberId,
  });

  @override
  Future<Result<void>> setGroupMemberRole({
    required String groupId,
    required String memberId,
    required GroupMemberRole role,
  }) => _voidCall('setGroupMemberRole', <String, Object?>{
    'groupId': groupId,
    'memberId': memberId,
    'role': role.name,
  });

  @override
  Future<Result<void>> transferGroupOwnership({
    required String groupId,
    required String newOwnerId,
  }) => _voidCall('transferGroupOwnership', <String, Object?>{
    'groupId': groupId,
    'newOwnerId': newOwnerId,
  });

  @override
  Future<Result<void>> leaveGroup(String groupId) =>
      _voidCall('leaveGroup', <String, Object?>{'groupId': groupId});

  @override
  Future<Result<void>> deleteGroup(String groupId) =>
      _voidCall('deleteGroup', <String, Object?>{'groupId': groupId});

  @override
  Future<Result<List<GroupMember>>> listGroupMembers(String groupId) async {
    try {
      final Map<String, dynamic> response = await _call(
        'listGroupMembers',
        <String, Object?>{'groupId': groupId},
      );
      return Success<List<GroupMember>>(
        asMapList(response['members'])
            .map((Map<String, dynamic> item) => groupMemberFromMap(item))
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<GroupMember>>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<List<GroupMember>>(
        GroupsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<List<GroupJoinRequest>>> listGroupJoinRequests(
    String groupId,
  ) async {
    try {
      final Map<String, dynamic> response = await _call(
        'listGroupJoinRequests',
        <String, Object?>{'groupId': groupId},
      );
      return Success<List<GroupJoinRequest>>(
        asMapList(response['requests'])
            .map((Map<String, dynamic> item) => groupJoinRequestFromMap(item))
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<GroupJoinRequest>>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<List<GroupJoinRequest>>(
        GroupsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<List<GroupPendingInvitation>>> listGroupPendingInvitations(
    String groupId,
  ) async {
    try {
      final Map<String, dynamic> response = await _call(
        'listGroupPendingInvitations',
        <String, Object?>{'groupId': groupId},
      );
      return Success<List<GroupPendingInvitation>>(
        asMapList(response['invitations'])
            .map(
              (Map<String, dynamic> item) =>
                  groupPendingInvitationFromMap(item),
            )
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<GroupPendingInvitation>>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<List<GroupPendingInvitation>>(
        GroupsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<List<GroupInvitation>>> listMyGroupInvitations() async {
    try {
      final Map<String, dynamic> response = await _call(
        'listMyGroupInvitations',
        const <String, Object?>{},
      );
      return Success<List<GroupInvitation>>(
        asMapList(response['invitations'])
            .map((Map<String, dynamic> item) => groupInvitationFromMap(item))
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<GroupInvitation>>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<List<GroupInvitation>>(
        GroupsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<String>> createGroupSession(
    CreateGroupSessionRequest request,
  ) async {
    try {
      final Map<String, dynamic> response =
          await _call('createGroupSession', <String, Object?>{
            'groupId': request.groupId,
            'title': request.title,
            'sessionType': request.sessionType.wireValue,
            'activity': request.activity.isEmpty
                ? request.sessionType.wireValue
                : request.activity,
            'startAt': request.startAt.toUtc().toIso8601String(),
            'endAt': request.endAt.toUtc().toIso8601String(),
            'description': request.description,
            'capacity': request.capacity,
            if (!request.location.isEmpty) 'location': request.location.toMap(),
          });
      return Success<String>(_requiredString(response, 'sessionId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(GroupsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<String>(GroupsFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> updateGroupSession(UpdateGroupSessionRequest request) =>
      _voidCall('updateGroupSession', <String, Object?>{
        'groupId': request.groupId,
        'sessionId': request.sessionId,
        if (request.title != null) 'title': request.title,
        if (request.sessionType != null)
          'sessionType': request.sessionType!.wireValue,
        if (request.activity != null) 'activity': request.activity,
        if (request.description != null) 'description': request.description,
        if (request.startAt != null)
          'startAt': request.startAt!.toUtc().toIso8601String(),
        if (request.endAt != null)
          'endAt': request.endAt!.toUtc().toIso8601String(),
        if (request.capacity != null) 'capacity': request.capacity,
        if (request.location != null) 'location': request.location!.toMap(),
      });

  @override
  Future<Result<void>> cancelGroupSession({
    required String groupId,
    required String sessionId,
  }) => _voidCall('cancelGroupSession', <String, Object?>{
    'groupId': groupId,
    'sessionId': sessionId,
  });

  @override
  Future<Result<List<GroupSession>>> listGroupSessions(String groupId) async {
    try {
      final Map<String, dynamic> response = await _call(
        'listGroupSessions',
        <String, Object?>{'groupId': groupId},
      );
      return Success<List<GroupSession>>(
        asMapList(response['sessions'])
            .map((Map<String, dynamic> item) => groupSessionFromMap(item))
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<GroupSession>>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<List<GroupSession>>(
        GroupsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> respondToGroupSessionRsvp({
    required String groupId,
    required String sessionId,
    required GroupSessionRsvpStatus status,
  }) => _voidCall('respondToGroupSessionRsvp', <String, Object?>{
    'groupId': groupId,
    'sessionId': sessionId,
    'status': status.wireValue,
  });

  @override
  Future<Result<List<GroupChannel>>> getGroupChannels(String groupId) async {
    try {
      final Map<String, dynamic> response = await _call(
        'getGroupChannels',
        <String, Object?>{'groupId': groupId},
      );
      return Success<List<GroupChannel>>(
        asMapList(response['channels'])
            .map((Map<String, dynamic> item) => groupChannelFromMap(item))
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<GroupChannel>>(
        GroupsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<List<GroupChannel>>(
        GroupsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<String>> reportGroup({
    required String groupId,
    required String reason,
    String? details,
  }) async {
    try {
      final Map<String, dynamic> response =
          await _call('reportGroup', <String, Object?>{
            'groupId': groupId,
            'reason': reason,
            if (details != null && details.isNotEmpty) 'details': details,
          });
      return Success<String>(_requiredString(response, 'reportId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(GroupsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<String>(GroupsFailureMapper.unexpected(error));
    }
  }

  Future<Result<void>> _voidCall(String name, Map<String, Object?> data) async {
    try {
      await _call(name, data);
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(GroupsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<void>(GroupsFailureMapper.unexpected(error));
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final HttpsCallableResult<dynamic> response = await _functions
        .httpsCallable(name)
        .call<dynamic>(data);
    return asStringKeyedMap(response.data);
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('The groups service omitted $key.');
  }
}
