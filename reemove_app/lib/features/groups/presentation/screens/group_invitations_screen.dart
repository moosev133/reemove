import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group_invitation.dart';

class GroupInvitationsScreen extends ConsumerWidget {
  const GroupInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GroupInvitation>> invitationsValue = ref.watch(
      myGroupInvitationsProvider,
    );
    final AsyncValue<void> action = ref.watch(groupsActionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Group invitations')),
      body: invitationsValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppErrorView(
          title: 'Invitations unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(myGroupInvitationsProvider),
        ),
        data: (List<GroupInvitation> invitations) {
          if (invitations.isEmpty) {
            return AdaptivePageBody(
              slivers: const <Widget>[
                AppEmptyState(
                  icon: Icons.mail_outline_rounded,
                  title: 'No pending invitations',
                  message:
                      'When someone invites you to a group, it will appear here.',
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myGroupInvitationsProvider);
              await ref.read(myGroupInvitationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: invitations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final GroupInvitation invitation = invitations[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () =>
                      context.push(AppRoutes.groupDetail(invitation.groupId)),
                  leading: AppAvatar(
                    displayName: invitation.snapshot.name,
                    imageUrl: invitation.snapshot.avatarUrl,
                  ),
                  title: Text(invitation.snapshot.name),
                  subtitle: Text(
                    '${invitation.snapshot.memberCount} members'
                    '${invitation.snapshot.category.isNotEmpty ? ' · ${invitation.snapshot.category}' : ''}',
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Decline invitation',
                        onPressed: action.isLoading
                            ? null
                            : () => _respond(context, ref, invitation, accept: false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Accept invitation',
                        onPressed: action.isLoading
                            ? null
                            : () => _respond(context, ref, invitation, accept: true),
                        icon: const Icon(Icons.check_rounded),
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

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    GroupInvitation invitation, {
    required bool accept,
  }) async {
    final bool ok = await ref
        .read(groupsActionControllerProvider.notifier)
        .respondToGroupInvitation(groupId: invitation.groupId, accept: accept);
    if (!context.mounted || !ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accept
              ? 'You joined ${invitation.snapshot.name}.'
              : 'Invitation declined.',
        ),
      ),
    );
  }
}
