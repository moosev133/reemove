import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/debug/staging_diagnostics.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../messages/presentation/screens/conversation_screen.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_channel.dart';
import '../../domain/entities/group_enums.dart';
import '../../domain/entities/sports_group_channel_context.dart';

/// Opens a sports-group channel conversation with publish/media constraints.
class GroupChannelConversationScreen extends ConsumerWidget {
  const GroupChannelConversationScreen({
    required this.groupId,
    required this.channelType,
    this.focusMessageId,
    super.key,
  });

  final String groupId;
  final String channelType;
  final String? focusMessageId;

  GroupChannelType get _parsedType => parseGroupChannelType(channelType);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Group> groupValue = ref.watch(groupProvider(groupId));
    final AsyncValue<List<GroupChannel>> channelsValue = ref.watch(
      groupChannelsProvider(groupId),
    );

    return groupValue.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: const Text('Channel')),
        body: AppErrorView(
          title: 'Channel unavailable',
          message: error.toString(),
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
      ),
      data: (Group group) {
        if (!group.isMember) {
          return Scaffold(
            appBar: AppBar(title: const Text('Channel')),
            body: const AppEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Unavailable',
              message:
                  'This channel is only available to active group members.',
            ),
          );
        }
        return channelsValue.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (Object error, StackTrace _) => Scaffold(
            appBar: AppBar(title: Text(_parsedType.displayLabel)),
            body: AppErrorView(
              title: 'Could not open channel',
              message: error.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(groupChannelsProvider(groupId)),
            ),
          ),
          data: (List<GroupChannel> channels) {
            GroupChannel? channel;
            for (final GroupChannel item in channels) {
              if (item.type == _parsedType) {
                channel = item;
                break;
              }
            }
            if (channel == null || channel.conversationId.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: Text(_parsedType.displayLabel)),
                body: AppEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Channel not ready',
                  message: 'Try again in a moment.',
                  actionLabel: 'Channels',
                  onAction: () => context.go(AppRoutes.groupChannels(groupId)),
                ),
              );
            }
            final GroupMemberRole role =
                group.viewerRole ?? GroupMemberRole.member;
            final bool canPublish = channel.canPublish(role);

            final String? currentUid =
                ref.watch(currentAuthUserProvider).value?.uid;
            StagingDiagnostics.log(
              'GROUP_CHANNEL_CONVERSATION_SCREEN_BUILT',
              <String, Object?>{
                'currentUserUid': currentUid,
                'groupId': groupId,
                'groupOwnerId': group.ownerId,
                'groupViewerRole': group.viewerRole?.name,
                'membershipStatus': group.membershipStatus.name,
                'groupIsManager': group.isManager,
                'channelType': channel.type.wireValue,
                'conversationId': channel.conversationId,
                'sportsContext.canModerate':
                    group.canModerateAs(currentUid),
                'sportsContext.canModerateNav': group.canModerateAs(currentUid),
              },
            );
            return ConversationScreen(
              conversationId: channel.conversationId,
              sportsGroupContext: SportsGroupChannelContext(
                groupId: groupId,
                groupName: group.name,
                channelType: channel.type,
                canPublish: canPublish,
                canModerate: group.canModerateAs(
                  ref.watch(currentAuthUserProvider).value?.uid,
                ),
                supportedMediaModes: channel.supportedMediaModes,
                viewOnceSupported: channel.viewOnceSupported,
                focusMessageId: focusMessageId,
              ),
            );
          },
        );
      },
    );
  }
}
