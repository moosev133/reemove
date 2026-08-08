import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_enums.dart';
import '../../domain/entities/group_member.dart';
import '../widgets/group_membership_badge.dart';

class GroupMembersScreen extends ConsumerWidget {
  const GroupMembersScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GroupMember>> membersValue = ref.watch(
      groupMembersProvider(groupId),
    );
    final AsyncValue<Group> groupValue = ref.watch(groupProvider(groupId));
    final AuthUser? viewer = ref.watch(currentAuthUserProvider).value;
    final Group? group = groupValue.value;
    final bool isOwner = group?.isOwner ?? false;
    final bool isManager = group?.isManager ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              key: const Key('group-members-invite-fab'),
              onPressed: () => context.push(AppRoutes.groupInvite(groupId)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Invite'),
            )
          : null,
      body: membersValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppErrorView(
          title: 'Members unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(groupMembersProvider(groupId)),
        ),
        data: (List<GroupMember> members) {
          if (members.isEmpty) {
            return AdaptivePageBody(
              slivers: const <Widget>[
                AppEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No members yet',
                  message: 'Members will appear here once they join.',
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupMembersProvider(groupId));
              await ref.read(groupMembersProvider(groupId).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final GroupMember member = members[index];
                final bool isSelf = member.userId == viewer?.uid;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () =>
                      context.push(AppRoutes.publicProfile(member.username)),
                  leading: AppAvatar(
                    displayName: member.displayName,
                    imageUrl: member.avatarUrl,
                  ),
                  title: Text(member.displayName),
                  subtitle: Text('@${member.username}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(groupMemberRoleLabel(member.role)),
                      if (!isSelf &&
                          (isOwner ||
                              (isManager &&
                                  member.role == GroupMemberRole.member)))
                        PopupMenuButton<String>(
                          tooltip: 'Manage member',
                          onSelected: (String value) =>
                              _handleAction(context, ref, member, value),
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                if (isOwner &&
                                    member.role == GroupMemberRole.member)
                                  const PopupMenuItem<String>(
                                    value: 'promote',
                                    child: Text('Make admin'),
                                  ),
                                if (isOwner &&
                                    member.role == GroupMemberRole.admin)
                                  const PopupMenuItem<String>(
                                    value: 'demote',
                                    child: Text('Remove admin'),
                                  ),
                                if (isOwner)
                                  const PopupMenuItem<String>(
                                    value: 'transfer',
                                    child: Text('Transfer ownership'),
                                  ),
                                const PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Text('Remove from group'),
                                ),
                              ],
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
    String action,
  ) async {
    switch (action) {
      case 'promote':
        await _setRole(context, ref, member, GroupMemberRole.admin);
      case 'demote':
        await _setRole(context, ref, member, GroupMemberRole.member);
      case 'transfer':
        await _transferOwnership(context, ref, member);
      case 'remove':
        await _remove(context, ref, member);
    }
  }

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
    GroupMemberRole role,
  ) async {
    final bool ok = await ref
        .read(groupsActionControllerProvider.notifier)
        .setGroupMemberRole(
          groupId: groupId,
          memberId: member.userId,
          role: role,
        );
    if (!context.mounted || !ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${member.displayName} is now ${groupMemberRoleLabel(role).toLowerCase()}.',
        ),
      ),
    );
  }

  Future<void> _transferOwnership(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Transfer ownership to ${member.displayName}?'),
            content: const Text(
              'You will become an admin and lose owner-only controls.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Transfer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final bool ok = await ref
        .read(groupsActionControllerProvider.notifier)
        .transferGroupOwnership(groupId: groupId, newOwnerId: member.userId);
    if (!context.mounted || !ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${member.displayName} now owns this group.')),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Remove ${member.displayName}?'),
            content: const Text('They can request to join again later.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final bool ok = await ref
        .read(groupsActionControllerProvider.notifier)
        .removeGroupMember(groupId: groupId, memberId: member.userId);
    if (!context.mounted || !ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${member.displayName} was removed.')),
    );
  }
}
