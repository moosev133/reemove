import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_enums.dart';
import '../../domain/entities/group_requests.dart';
import '../widgets/group_membership_badge.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Group> groupValue = ref.watch(groupProvider(groupId));
    final AsyncValue<void> action = ref.watch(groupsActionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group'),
        actions: <Widget>[
          groupValue.maybeWhen(
            data: (Group group) => PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (String value) =>
                  _handleMenuAction(context, ref, group, value),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (group.isManager)
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit group'),
                  ),
                if (group.isManager)
                  const PopupMenuItem<String>(
                    value: 'requests',
                    child: Text('Join requests'),
                  ),
                if (group.isManager)
                  const PopupMenuItem<String>(
                    value: 'schedule',
                    child: Text('Schedule'),
                  ),
                if (group.isOwner)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete group'),
                  ),
                if (!group.isOwner)
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Text('Report group'),
                  ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: groupValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppErrorView(
          title: 'Group unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(groupProvider(groupId)),
        ),
        data: (Group group) {
          return AdaptivePageBody(
            slivers: <Widget>[
              AppPageHeader(
                eyebrow: group.category.isEmpty
                    ? 'Group'
                    : group.category.toUpperCase(),
                title: group.name,
                subtitle: group.description,
                trailing: AppAvatar(
                  displayName: group.name,
                  imageUrl: group.avatarUrl,
                  radius: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppStatusChip(
                    label: '${group.memberCount} members',
                    icon: Icons.groups_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  AppStatusChip(
                    label: groupPrivacyLabel(group.privacy),
                    icon: groupPrivacyIcon(group.privacy),
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  if (group.location.displayLabel.isNotEmpty)
                    AppStatusChip(
                      label: group.location.displayLabel,
                      icon: Icons.location_on_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _MembershipButton(
                group: group,
                isLoading: action.isLoading,
                onJoin: () => _requestJoin(context, ref, group),
                onCancelRequest: () => _cancelRequest(context, ref, group),
                onLeave: () => _leave(context, ref, group),
              ),
              if (action.hasError) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  action.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (group.isMember) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                Text('Manage', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                PremiumSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.people_outline_rounded),
                        title: const Text('Members'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.push(AppRoutes.groupMembers(groupId)),
                      ),
                      if (group.isManager) ...<Widget>[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.person_add_alt_1_outlined,
                          ),
                          title: const Text('Join requests'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(
                            AppRoutes.groupJoinRequests(groupId),
                          ),
                        ),
                      ],
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Schedule'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.push(AppRoutes.groupSchedule(groupId)),
                      ),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                const AppEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Join to see more',
                  message:
                      'Members get access to the schedule, roster, and group chat.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    Group group,
    String value,
  ) async {
    switch (value) {
      case 'edit':
        await context.push(AppRoutes.editGroup(groupId));
      case 'requests':
        await context.push(AppRoutes.groupJoinRequests(groupId));
      case 'schedule':
        await context.push(AppRoutes.groupSchedule(groupId));
      case 'delete':
        await _confirmDelete(context, ref, group);
      case 'report':
        await _report(context, ref);
    }
  }

  Future<void> _requestJoin(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final GroupJoinOutcome? outcome = await ref
        .read(groupsActionControllerProvider.notifier)
        .requestJoinGroup(groupId);
    if (!context.mounted || outcome == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == GroupJoinOutcome.pending
              ? 'Join request sent.'
              : 'You joined ${group.name}.',
        ),
      ),
    );
  }

  Future<void> _cancelRequest(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final bool ok = await ref
        .read(groupsActionControllerProvider.notifier)
        .cancelJoinRequest(groupId);
    if (!context.mounted || !ok) {
      return;
    }
    ref.invalidate(groupProvider(groupId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Join request canceled.')),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Group group) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Leave ${group.name}?'),
            content: const Text('You can request to join again later.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Leave'),
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
        .leaveGroup(groupId);
    if (!context.mounted || !ok) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('You left the group.')));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Delete ${group.name}?'),
            content: const Text(
              'This removes the group for everyone. This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
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
        .deleteGroup(groupId);
    if (!context.mounted || !ok) {
      return;
    }
    context.go(AppRoutes.groups);
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final TextEditingController reasonController = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Report group'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'spam, harassment, impersonation…',
          ),
          maxLength: 64,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) {
      return;
    }
    final String? reportId = await ref
        .read(groupsActionControllerProvider.notifier)
        .reportGroup(groupId: groupId, reason: reason);
    if (!context.mounted || reportId == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report submitted. Thank you.')));
  }
}

class _MembershipButton extends StatelessWidget {
  const _MembershipButton({
    required this.group,
    required this.isLoading,
    required this.onJoin,
    required this.onCancelRequest,
    required this.onLeave,
  });

  final Group group;
  final bool isLoading;
  final VoidCallback onJoin;
  final VoidCallback onCancelRequest;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (group.isOwner) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.workspace_premium_outlined),
        label: const Text('You own this group'),
      );
    }
    if (group.isManager) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onLeave,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Leave group'),
      );
    }
    if (group.isMember) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onLeave,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Leave group'),
      );
    }
    if (group.hasPendingRequest) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onCancelRequest,
        icon: const Icon(Icons.hourglass_top_rounded),
        label: const Text('Cancel join request'),
      );
    }
    final bool disabled =
        isLoading || group.isFull || group.joinPolicy == GroupJoinPolicy.inviteOnly;
    return FilledButton.icon(
      onPressed: disabled ? null : onJoin,
      icon: const Icon(Icons.group_add_rounded),
      label: Text(
        group.isFull
            ? 'Group is full'
            : group.joinPolicy == GroupJoinPolicy.inviteOnly
            ? 'Invite only'
            : group.joinPolicy == GroupJoinPolicy.approvalRequired
            ? 'Request to join'
            : 'Join group',
      ),
    );
  }
}
