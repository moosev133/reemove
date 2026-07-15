import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/domain/entities/profile_connection.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../application/messaging_providers.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/messaging_action.dart';

class ConversationDetailsScreen extends ConsumerWidget {
  const ConversationDetailsScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Conversation?> conversation = ref.watch(
      conversationProvider(conversationId),
    );
    final AuthUser? user = ref.watch(currentAuthUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation details')),
      body: conversation.when(
        data: (Conversation? value) {
          if (value == null || user == null) {
            return const Center(child: Text('Conversation unavailable.'));
          }
          final ConversationMember? me = value.member(user.uid);
          final bool muted = me?.mutedUntil?.isAfter(DateTime.now()) ?? false;
          final bool archived = me?.archivedAt != null;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Center(
                child: Column(
                  children: <Widget>[
                    AppAvatar(
                      displayName: value.title,
                      imageUrl: value.avatarUrl,
                      radius: 46,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      value.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      value.isGroup
                          ? '${value.memberCount} members'
                          : 'Private conversation',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (value.isGroup && (me?.isAdmin ?? false)) ...<Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rename group'),
                  onTap: () => _renameGroup(context, ref, value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: const Text('Add members'),
                  onTap: () => _addMembers(context, ref, value, user),
                ),
                const Divider(height: AppSpacing.xl),
              ],
              SwitchListTile.adaptive(
                value: !muted,
                title: const Text('Message notifications'),
                subtitle: Text(muted ? 'Muted' : 'Enabled'),
                onChanged: (bool enabled) async {
                  await ref
                      .read(messagingActionControllerProvider.notifier)
                      .updatePreferences(
                        ConversationPreferencesUpdate(
                          conversationId: conversationId,
                          notificationsEnabled: enabled,
                          mutedUntil: enabled
                              ? DateTime.now().subtract(
                                  const Duration(minutes: 1),
                                )
                              : DateTime.now().add(const Duration(days: 3650)),
                        ),
                      );
                },
              ),
              SwitchListTile.adaptive(
                value: archived,
                title: const Text('Archive conversation'),
                subtitle: const Text('Move it out of your active inbox'),
                onChanged: (bool value) async {
                  await ref
                      .read(messagingActionControllerProvider.notifier)
                      .updatePreferences(
                        ConversationPreferencesUpdate(
                          conversationId: conversationId,
                          archived: value,
                        ),
                      );
                },
              ),
              const Divider(height: AppSpacing.xl),
              Text('Members', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              for (final ConversationMember member in value.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppAvatar(
                    displayName: member.user.displayName,
                    imageUrl: member.user.avatarUrl,
                  ),
                  title: Text(member.user.displayName),
                  subtitle: Text(
                    '@${member.user.username} · ${member.role.name}',
                  ),
                  trailing: member.user.id == user.uid
                      ? const Text('You')
                      : value.isGroup &&
                            (me?.isAdmin ?? false) &&
                            member.role != ConversationMemberRole.owner
                      ? IconButton(
                          tooltip: 'Remove member',
                          onPressed: () =>
                              _removeMember(context, ref, value, member),
                          icon: const Icon(Icons.person_remove_outlined),
                        )
                      : null,
                ),
              if (value.isGroup) ...<Widget>[
                const Divider(height: AppSpacing.xl),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  textColor: Theme.of(context).colorScheme.error,
                  iconColor: Theme.of(context).colorScheme.error,
                  leading: const Icon(Icons.exit_to_app_rounded),
                  title: const Text('Leave group'),
                  onTap: () => _confirmLeave(context, ref),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Future<void> _renameGroup(
    BuildContext context,
    WidgetRef ref,
    Conversation conversation,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: conversation.title,
    );
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.length < 2) {
      return;
    }
    await ref
        .read(messagingActionControllerProvider.notifier)
        .updateGroup(conversationId: conversation.id, title: title);
  }

  Future<void> _addMembers(
    BuildContext context,
    WidgetRef ref,
    Conversation conversation,
    AuthUser user,
  ) async {
    final ProfileConnectionPage page = await ref.read(
      profileConnectionsProvider(
        ProfileConnectionsQuery(
          profileId: user.uid,
          type: ProfileConnectionType.following,
        ),
      ).future,
    );
    if (!context.mounted) {
      return;
    }
    final Set<String> existing = conversation.members
        .map((ConversationMember member) => member.user.id)
        .toSet();
    final List<UserProfile> candidates = page.items
        .where((UserProfile profile) => !existing.contains(profile.uid))
        .toList(growable: false);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible people to add.')),
      );
      return;
    }
    final Set<String> selected = <String>{};
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('Add members'),
              content: SizedBox(
                width: 460,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (BuildContext context, int index) {
                    final UserProfile profile = candidates[index];
                    return CheckboxListTile(
                      value: selected.contains(profile.uid),
                      title: Text(profile.displayName),
                      subtitle: Text('@${profile.username}'),
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value ?? false) {
                            selected.add(profile.uid);
                          } else {
                            selected.remove(profile.uid);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Add'),
                ),
              ],
            ),
      ),
    );
    if (confirmed != true || selected.isEmpty) {
      return;
    }
    await ref
        .read(messagingActionControllerProvider.notifier)
        .updateGroup(
          conversationId: conversation.id,
          addMemberIds: selected.toList(growable: false),
        );
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    Conversation conversation,
    ConversationMember member,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Remove ${member.user.displayName}?'),
        content: const Text(
          'They will lose access to new messages and attachments in this group.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(messagingActionControllerProvider.notifier)
        .updateGroup(
          conversationId: conversation.id,
          removeMemberIds: <String>[member.user.id],
        );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Leave this group?'),
        content: const Text(
          'You will stop receiving new messages and may need another member to invite you again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final bool left = await ref
        .read(messagingActionControllerProvider.notifier)
        .leaveConversation(conversationId);
    if (left && context.mounted) {
      context.go(AppRoutes.messages);
    }
  }
}
