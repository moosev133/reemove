import 'group_enums.dart';

/// A group-owned conversation channel and its C1 media contract.
///
/// See [GroupMediaMode] for the Phase C2 note: [viewOnceSupported] is always
/// `false` in C1 regardless of what [supportedMediaModes] lists, because the
/// actual disappearing-media runtime behavior has not shipped yet.
class GroupChannel {
  const GroupChannel({
    required this.channelId,
    required this.type,
    required this.conversationId,
    required this.supportedMediaModes,
    required this.publishRoles,
    required this.readRoles,
    this.normalMediaSupported = true,
    this.keepInChatSupported = true,
    this.viewOnceSupported = false,
  });

  final String channelId;
  final GroupChannelType type;
  final String conversationId;
  final List<GroupMediaMode> supportedMediaModes;
  final List<GroupMemberRole> publishRoles;
  final List<GroupMemberRole> readRoles;
  final bool normalMediaSupported;
  final bool keepInChatSupported;
  final bool viewOnceSupported;

  bool canPublish(GroupMemberRole role) => publishRoles.contains(role);
  bool canRead(GroupMemberRole role) => readRoles.contains(role);
}
