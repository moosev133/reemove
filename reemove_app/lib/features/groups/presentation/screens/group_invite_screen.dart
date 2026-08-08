import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/domain/entities/profile_connection.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';

/// Manager-only screen to invite followers into a sports group.
///
/// Eligible invitees are people who follow the current manager (server rule).
/// Existing members and users with a pending invitation are excluded from the
/// invite list and shown under Pending when applicable.
class GroupInviteScreen extends ConsumerStatefulWidget {
  const GroupInviteScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends ConsumerState<GroupInviteScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Group> groupValue = ref.watch(
      groupProvider(widget.groupId),
    );
    final AuthUser? viewer = ref.watch(currentAuthUserProvider).value;
    final AsyncValue<void> action = ref.watch(groupsActionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite members')),
      body: groupValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppErrorView(
          title: 'Group unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(groupProvider(widget.groupId)),
        ),
        data: (Group group) {
          if (!group.isManager) {
            return const AdaptivePageBody(
              slivers: <Widget>[
                AppEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Managers only',
                  message:
                      'Only owners and admins can send group invitations.',
                ),
              ],
            );
          }
          if (viewer == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _InviteBody(
            groupId: widget.groupId,
            viewerId: viewer.uid,
            searchController: _search,
            query: _query,
            busy: action.isLoading,
            onQueryChanged: (String value) => setState(() => _query = value),
          );
        },
      ),
    );
  }
}

class _InviteBody extends ConsumerWidget {
  const _InviteBody({
    required this.groupId,
    required this.viewerId,
    required this.searchController,
    required this.query,
    required this.busy,
    required this.onQueryChanged,
  });

  final String groupId;
  final String viewerId;
  final TextEditingController searchController;
  final String query;
  final bool busy;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GroupMember>> membersValue = ref.watch(
      groupMembersProvider(groupId),
    );
    final AsyncValue<List<GroupPendingInvitation>> pendingValue = ref.watch(
      groupPendingInvitationsProvider(groupId),
    );
    final AsyncValue<ProfileConnectionPage> followersValue = ref.watch(
      profileConnectionsProvider(
        ProfileConnectionsQuery(
          profileId: viewerId,
          type: ProfileConnectionType.followers,
        ),
      ),
    );

    if (membersValue.isLoading ||
        pendingValue.isLoading ||
        followersValue.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (membersValue.hasError) {
      return AppErrorView(
        title: 'Members unavailable',
        message: membersValue.error.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(groupMembersProvider(groupId)),
      );
    }
    if (pendingValue.hasError) {
      return AppErrorView(
        title: 'Pending invitations unavailable',
        message: pendingValue.error.toString(),
        actionLabel: 'Retry',
        onAction: () =>
            ref.invalidate(groupPendingInvitationsProvider(groupId)),
      );
    }
    if (followersValue.hasError) {
      return AppErrorView(
        title: 'Followers unavailable',
        message: followersValue.error.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(
          profileConnectionsProvider(
            ProfileConnectionsQuery(
              profileId: viewerId,
              type: ProfileConnectionType.followers,
            ),
          ),
        ),
      );
    }

    final List<GroupMember> members = membersValue.value ?? const <GroupMember>[];
    final List<GroupPendingInvitation> pending =
        pendingValue.value ?? const <GroupPendingInvitation>[];
    final List<UserProfile> followers =
        followersValue.value?.items ?? const <UserProfile>[];

    final Set<String> memberIds = members
        .map((GroupMember m) => m.userId)
        .toSet();
    final Set<String> pendingIds = pending
        .map((GroupPendingInvitation i) => i.inviteeId)
        .toSet();
    final String needle = query.trim().toLowerCase();

    final List<UserProfile> eligible = followers.where((UserProfile profile) {
      if (memberIds.contains(profile.uid)) {
        return false;
      }
      if (pendingIds.contains(profile.uid)) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return profile.displayName.toLowerCase().contains(needle) ||
          profile.username.toLowerCase().contains(needle);
    }).toList(growable: false);

    final List<GroupPendingInvitation> filteredPending = pending.where((
      GroupPendingInvitation invitation,
    ) {
      if (needle.isEmpty) {
        return true;
      }
      return invitation.displayName.toLowerCase().contains(needle) ||
          invitation.username.toLowerCase().contains(needle);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(groupMembersProvider(groupId));
        ref.invalidate(groupPendingInvitationsProvider(groupId));
        ref.invalidate(
          profileConnectionsProvider(
            ProfileConnectionsQuery(
              profileId: viewerId,
              type: ProfileConnectionType.followers,
            ),
          ),
        );
        await Future.wait(<Future<Object?>>[
          ref.read(groupMembersProvider(groupId).future),
          ref.read(groupPendingInvitationsProvider(groupId).future),
          ref.read(
            profileConnectionsProvider(
              ProfileConnectionsQuery(
                profileId: viewerId,
                type: ProfileConnectionType.followers,
              ),
            ).future,
          ),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              labelText: 'Search followers',
              hintText: 'Name or username',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You can invite people who follow you. Existing members and '
            'pending invitees are hidden from this list.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Pending invitations (${filteredPending.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (filteredPending.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                needle.isEmpty
                    ? 'No pending invitations.'
                    : 'No pending invitations match your search.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...filteredPending.map(
              (GroupPendingInvitation invitation) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppAvatar(
                  displayName: invitation.displayName,
                  imageUrl: invitation.avatarUrl,
                ),
                title: Text(invitation.displayName),
                subtitle: Text('@${invitation.username} · Pending'),
                trailing: IconButton(
                  tooltip: 'Cancel invitation',
                  onPressed: busy
                      ? null
                      : () => _cancel(context, ref, invitation),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Eligible followers (${eligible.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (followers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'People must follow you before you can invite them to a group.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (eligible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                needle.isEmpty
                    ? 'Your followers are already members or already invited.'
                    : 'No followers match your search.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...eligible.map(
              (UserProfile profile) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppAvatar(
                  displayName: profile.displayName,
                  imageUrl: profile.avatarUrl,
                ),
                title: Text(profile.displayName),
                subtitle: Text('@${profile.username}'),
                trailing: FilledButton.tonal(
                  onPressed: busy
                      ? null
                      : () => _invite(context, ref, profile),
                  child: const Text('Invite'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final bool? created = await ref
        .read(groupsActionControllerProvider.notifier)
        .inviteToGroup(groupId: groupId, inviteeId: profile.uid);
    if (!context.mounted) {
      return;
    }
    if (created == null) {
      final Object? error = ref.read(groupsActionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error?.toString() ?? 'Could not send invitation.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created
              ? 'Invitation sent to @${profile.username}.'
              : '@${profile.username} is already a member or already invited.',
        ),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    GroupPendingInvitation invitation,
  ) async {
    final bool ok = await ref
        .read(groupsActionControllerProvider.notifier)
        .cancelGroupInvitation(
          groupId: groupId,
          inviteeId: invitation.inviteeId,
        );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Cancelled invitation for @${invitation.username}.'
              : 'Could not cancel invitation.',
        ),
      ),
    );
  }
}

