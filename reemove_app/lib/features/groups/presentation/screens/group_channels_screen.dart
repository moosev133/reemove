import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_channel.dart';
import '../../domain/entities/group_enums.dart';

class GroupChannelsScreen extends ConsumerWidget {
  const GroupChannelsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Group> groupValue = ref.watch(groupProvider(groupId));
    final AsyncValue<List<GroupChannel>> channelsValue = ref.watch(
      groupChannelsProvider(groupId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Channels')),
      body: groupValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppErrorView(
          title: 'Channels unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () {
            ref.invalidate(groupProvider(groupId));
            ref.invalidate(groupChannelsProvider(groupId));
          },
        ),
        data: (Group group) {
          if (!group.isMember) {
            return const AppEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Members only',
              message: 'Join this group to open member chat and announcements.',
            );
          }
          return channelsValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace _) => AppErrorView(
              title: 'Could not load channels',
              message: error.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(groupChannelsProvider(groupId)),
            ),
            data: (List<GroupChannel> channels) {
              if (channels.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No channels yet',
                  message: 'Channels will appear once the group is ready.',
                );
              }
              return AdaptivePageBody(
                slivers: <Widget>[
                  AppPageHeader(
                    eyebrow: 'GROUP',
                    title: group.name,
                    subtitle: 'Member chat and announcements for this group.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PremiumSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (int index = 0; index < channels.length; index++) ...<Widget>[
                          if (index > 0) const Divider(height: 1),
                          _ChannelTile(
                            groupId: groupId,
                            group: group,
                            channel: channels[index],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.groupId,
    required this.group,
    required this.channel,
  });

  final String groupId;
  final Group group;
  final GroupChannel channel;

  @override
  Widget build(BuildContext context) {
    final GroupMemberRole? role = group.viewerRole;
    final bool canPublish =
        role != null && channel.canPublish(role);
    final IconData icon = channel.type == GroupChannelType.announcements
        ? Icons.campaign_outlined
        : Icons.chat_bubble_outline_rounded;
    return ListTile(
      leading: Icon(icon),
      title: Text(channel.type.displayLabel),
      subtitle: Text(
        canPublish
            ? 'You can post in this channel'
            : channel.type == GroupChannelType.announcements
                ? 'Owner and admins can post announcements'
                : 'Read and send with other members',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(
        AppRoutes.groupChannel(groupId, channel.type.wireValue),
      ),
    );
  }
}
