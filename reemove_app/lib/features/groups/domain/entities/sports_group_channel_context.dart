import '../../domain/entities/group_enums.dart';

/// Context passed into messaging UI for sports-group channels.
class SportsGroupChannelContext {
  static const String sourceValue = 'sports_group';

  const SportsGroupChannelContext({
    required this.groupId,
    required this.groupName,
    required this.channelType,
    required this.canPublish,
    required this.canModerate,
    required this.supportedMediaModes,
    required this.viewOnceSupported,
    this.focusMessageId,
  });

  final String groupId;
  final String groupName;
  final GroupChannelType channelType;
  final bool canPublish;
  final bool canModerate;
  final List<GroupMediaMode> supportedMediaModes;
  final bool viewOnceSupported;
  final String? focusMessageId;
}
