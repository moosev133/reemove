import '../../messages/domain/entities/conversation.dart';
import '../domain/entities/group.dart';
import '../domain/entities/group_channel.dart';
import '../domain/entities/group_enums.dart';
import '../domain/entities/sports_group_channel_context.dart';

/// Resolves live sports-group channel context for messaging UI.
abstract final class SportsGroupChannelContextResolver {
  static String? resolvedGroupId({
    SportsGroupChannelContext? navigationContext,
    Conversation? conversation,
  }) =>
      navigationContext?.groupId ?? conversation?.sportsGroupId;

  static GroupChannelType resolvedChannelType({
    SportsGroupChannelContext? navigationContext,
    Conversation? conversation,
  }) =>
      navigationContext?.channelType ??
      parseGroupChannelType(conversation?.sportsChannelType);

  static bool resolvesSportsChannel({
    SportsGroupChannelContext? navigationContext,
    Conversation? conversation,
  }) =>
      navigationContext != null || (conversation?.isSportsGroupChannel ?? false);

  static SportsGroupChannelContext? resolve({
    required SportsGroupChannelContext? navigationContext,
    required Conversation? conversation,
    required Group? group,
    required GroupChannel? channel,
    required String? viewerUid,
  }) {
    if (!resolvesSportsChannel(
      navigationContext: navigationContext,
      conversation: conversation,
    )) {
      return null;
    }

    final String? groupId = resolvedGroupId(
      navigationContext: navigationContext,
      conversation: conversation,
    );
    if (groupId == null || groupId.isEmpty) {
      return navigationContext;
    }

    final GroupChannelType channelType = resolvedChannelType(
      navigationContext: navigationContext,
      conversation: conversation,
    );
    final GroupMemberRole role = group?.viewerRole ??
        _groupRoleFromConversation(conversation, viewerUid);
    final bool canModerate = group != null
        ? group.canModerateAs(viewerUid)
        : _canModerateFromConversation(conversation, viewerUid);
    final bool canModerateFromNavigation =
        navigationContext?.canModerate ?? false;
    final bool resolvedCanModerate =
        canModerate || canModerateFromNavigation;

    return SportsGroupChannelContext(
      groupId: groupId,
      groupName: group?.name ??
          navigationContext?.groupName ??
          conversation?.title ??
          'Group',
      channelType: channelType,
      canPublish: channel?.canPublish(role) ??
          navigationContext?.canPublish ??
          true,
      canModerate: resolvedCanModerate,
      supportedMediaModes: channel?.supportedMediaModes ??
          navigationContext?.supportedMediaModes ??
          const <GroupMediaMode>[GroupMediaMode.normal],
      viewOnceSupported: channel?.viewOnceSupported ??
          navigationContext?.viewOnceSupported ??
          false,
      focusMessageId: navigationContext?.focusMessageId,
    );
  }

  static GroupMemberRole _groupRoleFromConversation(
    Conversation? conversation,
    String? viewerUid,
  ) {
    if (conversation == null || viewerUid == null || viewerUid.isEmpty) {
      return GroupMemberRole.member;
    }
    return switch (conversation.member(viewerUid)?.role) {
      ConversationMemberRole.owner => GroupMemberRole.owner,
      ConversationMemberRole.admin => GroupMemberRole.admin,
      _ => GroupMemberRole.member,
    };
  }

  static bool _canModerateFromConversation(
    Conversation? conversation,
    String? viewerUid,
  ) {
    if (conversation == null || viewerUid == null || viewerUid.isEmpty) {
      return false;
    }
    final ConversationMember? member = conversation.member(viewerUid);
    if (member?.isAdmin ?? false) {
      return true;
    }
    // Sports-group conversations may lag group ACL sync; treat creator as manager.
    if (conversation.isSportsGroupChannel &&
        conversation.createdBy == viewerUid) {
      return true;
    }
    return false;
  }
}
