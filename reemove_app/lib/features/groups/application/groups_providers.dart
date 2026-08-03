import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/result/result.dart';
import '../data/repositories/firebase_groups_repository.dart';
import '../domain/entities/group.dart';
import '../domain/entities/group_channel.dart';
import '../domain/entities/group_enums.dart';
import '../domain/entities/group_invitation.dart';
import '../domain/entities/group_member.dart';
import '../domain/entities/group_membership.dart';
import '../domain/entities/group_requests.dart';
import '../domain/entities/group_session.dart';
import '../domain/repositories/groups_repository.dart';

final Provider<GroupsRepository> groupsRepositoryProvider =
    Provider<GroupsRepository>((Ref ref) {
      return FirebaseGroupsRepository(
        functions: ref.watch(firebaseFunctionsProvider),
      );
    });

/// `null` category means "all categories".
final discoverableGroupsProvider =
    FutureProvider.family<List<Group>, String?>((Ref ref, String? category) async {
      final Result<List<Group>> result = await ref
          .watch(groupsRepositoryProvider)
          .listDiscoverableGroups(category: category);
      return _value(result);
    });

final myGroupsProvider = FutureProvider<List<MyGroupMembership>>((Ref ref) async {
  final Result<List<MyGroupMembership>> result = await ref
      .watch(groupsRepositoryProvider)
      .listMyGroups();
  return _value(result);
});

final groupProvider = FutureProvider.family<Group, String>((
  Ref ref,
  String groupId,
) async {
  final Result<Group> result = await ref
      .watch(groupsRepositoryProvider)
      .getGroup(groupId);
  return _value(result);
});

final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((
  Ref ref,
  String groupId,
) async {
  final Result<List<GroupMember>> result = await ref
      .watch(groupsRepositoryProvider)
      .listGroupMembers(groupId);
  return _value(result);
});

final groupJoinRequestsProvider =
    FutureProvider.family<List<GroupJoinRequest>, String>((
      Ref ref,
      String groupId,
    ) async {
      final Result<List<GroupJoinRequest>> result = await ref
          .watch(groupsRepositoryProvider)
          .listGroupJoinRequests(groupId);
      return _value(result);
    });

final myGroupInvitationsProvider = FutureProvider<List<GroupInvitation>>((
  Ref ref,
) async {
  final Result<List<GroupInvitation>> result = await ref
      .watch(groupsRepositoryProvider)
      .listMyGroupInvitations();
  return _value(result);
});

final groupSessionsProvider = FutureProvider.family<List<GroupSession>, String>((
  Ref ref,
  String groupId,
) async {
  final Result<List<GroupSession>> result = await ref
      .watch(groupsRepositoryProvider)
      .listGroupSessions(groupId);
  return _value(result);
});

final groupChannelsProvider = FutureProvider.family<List<GroupChannel>, String>((
  Ref ref,
  String groupId,
) async {
  final Result<List<GroupChannel>> result = await ref
      .watch(groupsRepositoryProvider)
      .getGroupChannels(groupId);
  return _value(result);
});

final groupsActionControllerProvider =
    NotifierProvider<GroupsActionController, AsyncValue<void>>(
      GroupsActionController.new,
    );

class GroupsActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData<void>(null);

  Future<String?> createGroup(CreateGroupRequest request) => _stringAction(
    () => ref.read(groupsRepositoryProvider).createGroup(request),
    onSuccess: () {
      ref.invalidate(myGroupsProvider);
      ref.invalidate(discoverableGroupsProvider);
    },
  );

  Future<bool> updateGroup(UpdateGroupRequest request) => _resultAction(
    () => ref.read(groupsRepositoryProvider).updateGroup(request),
    onSuccess: () {
      ref.invalidate(groupProvider(request.groupId));
      ref.invalidate(myGroupsProvider);
      ref.invalidate(discoverableGroupsProvider);
    },
  );

  Future<GroupJoinOutcome?> requestJoinGroup(String groupId) =>
      _typedAction<GroupJoinOutcome>(
        () => ref.read(groupsRepositoryProvider).requestJoinGroup(groupId),
        onSuccess: () {
          ref.invalidate(groupProvider(groupId));
          ref.invalidate(myGroupsProvider);
        },
      );

  Future<bool> cancelJoinRequest(String groupId) => _resultAction(
    () => ref.read(groupsRepositoryProvider).cancelJoinRequest(groupId),
    onSuccess: () => ref.invalidate(groupProvider(groupId)),
  );

  Future<bool> respondToJoinRequest({
    required String groupId,
    required String requesterId,
    required bool approve,
  }) => _resultAction(
    () => ref.read(groupsRepositoryProvider).respondToJoinRequest(
      groupId: groupId,
      requesterId: requesterId,
      approve: approve,
    ),
    onSuccess: () {
      ref.invalidate(groupJoinRequestsProvider(groupId));
      ref.invalidate(groupMembersProvider(groupId));
      ref.invalidate(groupProvider(groupId));
    },
  );

  Future<bool?> inviteToGroup({
    required String groupId,
    required String inviteeId,
  }) => _typedAction<bool>(
    () => ref
        .read(groupsRepositoryProvider)
        .inviteToGroup(groupId: groupId, inviteeId: inviteeId),
  );

  Future<bool> respondToGroupInvitation({
    required String groupId,
    required bool accept,
  }) => _resultAction(
    () => ref
        .read(groupsRepositoryProvider)
        .respondToGroupInvitation(groupId: groupId, accept: accept),
    onSuccess: () {
      ref.invalidate(myGroupInvitationsProvider);
      ref.invalidate(myGroupsProvider);
      ref.invalidate(groupProvider(groupId));
    },
  );

  Future<bool> cancelGroupInvitation({
    required String groupId,
    required String inviteeId,
  }) => _resultAction(
    () => ref
        .read(groupsRepositoryProvider)
        .cancelGroupInvitation(groupId: groupId, inviteeId: inviteeId),
  );

  Future<bool> removeGroupMember({
    required String groupId,
    required String memberId,
  }) => _resultAction(
    () => ref
        .read(groupsRepositoryProvider)
        .removeGroupMember(groupId: groupId, memberId: memberId),
    onSuccess: () {
      ref.invalidate(groupMembersProvider(groupId));
      ref.invalidate(groupProvider(groupId));
    },
  );

  Future<bool> setGroupMemberRole({
    required String groupId,
    required String memberId,
    required GroupMemberRole role,
  }) => _resultAction(
    () => ref.read(groupsRepositoryProvider).setGroupMemberRole(
      groupId: groupId,
      memberId: memberId,
      role: role,
    ),
    onSuccess: () => ref.invalidate(groupMembersProvider(groupId)),
  );

  Future<bool> transferGroupOwnership({
    required String groupId,
    required String newOwnerId,
  }) => _resultAction(
    () => ref.read(groupsRepositoryProvider).transferGroupOwnership(
      groupId: groupId,
      newOwnerId: newOwnerId,
    ),
    onSuccess: () {
      ref.invalidate(groupMembersProvider(groupId));
      ref.invalidate(groupProvider(groupId));
    },
  );

  Future<bool> leaveGroup(String groupId) => _resultAction(
    () => ref.read(groupsRepositoryProvider).leaveGroup(groupId),
    onSuccess: () {
      ref.invalidate(myGroupsProvider);
      ref.invalidate(groupProvider(groupId));
    },
  );

  Future<bool> deleteGroup(String groupId) => _resultAction(
    () => ref.read(groupsRepositoryProvider).deleteGroup(groupId),
    onSuccess: () {
      ref.invalidate(myGroupsProvider);
      ref.invalidate(discoverableGroupsProvider);
    },
  );

  Future<String?> createGroupSession(CreateGroupSessionRequest request) =>
      _stringAction(
        () => ref.read(groupsRepositoryProvider).createGroupSession(request),
        onSuccess: () => ref.invalidate(groupSessionsProvider(request.groupId)),
      );

  Future<bool> updateGroupSession(UpdateGroupSessionRequest request) =>
      _resultAction(
        () => ref.read(groupsRepositoryProvider).updateGroupSession(request),
        onSuccess: () => ref.invalidate(groupSessionsProvider(request.groupId)),
      );

  Future<bool> cancelGroupSession({
    required String groupId,
    required String sessionId,
  }) => _resultAction(
    () => ref.read(groupsRepositoryProvider).cancelGroupSession(
      groupId: groupId,
      sessionId: sessionId,
    ),
    onSuccess: () => ref.invalidate(groupSessionsProvider(groupId)),
  );

  Future<String?> reportGroup({
    required String groupId,
    required String reason,
    String? details,
  }) => _stringAction(
    () => ref.read(groupsRepositoryProvider).reportGroup(
      groupId: groupId,
      reason: reason,
      details: details,
    ),
  );

  Future<String?> _stringAction(
    Future<Result<String>> Function() action, {
    void Function()? onSuccess,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final String value = _value(await action());
      state = const AsyncData<void>(null);
      onSuccess?.call();
      return value;
    } on Object catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return null;
    }
  }

  Future<bool> _resultAction(
    Future<Result<void>> Function() action, {
    void Function()? onSuccess,
  }) async {
    state = const AsyncLoading<void>();
    try {
      _value(await action());
      state = const AsyncData<void>(null);
      onSuccess?.call();
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return false;
    }
  }

  Future<T?> _typedAction<T>(
    Future<Result<T>> Function() action, {
    void Function()? onSuccess,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final T value = _value(await action());
      state = const AsyncData<void>(null);
      onSuccess?.call();
      return value;
    } on Object catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return null;
    }
  }
}

T _value<T>(Result<T> result) => switch (result) {
  Success<T>(:final T value) => value,
  FailureResult<T>(:final Failure failure) => throw failure,
};
