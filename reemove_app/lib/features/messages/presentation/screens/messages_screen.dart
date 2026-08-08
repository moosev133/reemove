import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../application/messaging_providers.dart';
import '../../domain/entities/conversation.dart';
import '../widgets/conversation_tile.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with AutomaticKeepAliveClientMixin<MessagesScreen> {
  String _query = '';
  bool _archived = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AsyncValue<List<ConversationSummary>> inbox = ref.watch(
      messagingInboxProvider(_archived),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: <Widget>[
          IconButton(
            tooltip: _archived ? 'Show active conversations' : 'Show archived',
            onPressed: () => setState(() => _archived = !_archived),
            icon: Icon(
              _archived ? Icons.inbox_rounded : Icons.archive_outlined,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Start conversation',
            icon: const Icon(Icons.edit_square),
            onSelected: (String value) {
              if (value == 'direct') {
                context.go(AppRoutes.newConversation);
              }
              if (value == 'group') {
                context.go(AppRoutes.newGroupConversation);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'direct',
                child: ListTile(
                  leading: Icon(Icons.person_add_alt_1_outlined),
                  title: Text('New message'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'group',
                child: ListTile(
                  leading: Icon(Icons.group_add_outlined),
                  title: Text('New group'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SearchBar(
              hintText: _archived
                  ? 'Search archived conversations'
                  : 'Search conversations',
              leading: const Icon(Icons.search_rounded),
              onChanged: (String value) {
                setState(() => _query = value.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: inbox.when(
              data: (List<ConversationSummary> items) {
                final List<ConversationSummary> filtered = items
                    .where((ConversationSummary item) {
                      if (_query.isEmpty) {
                        return true;
                      }
                      return item.title.toLowerCase().contains(_query) ||
                          item.members.any(
                            (member) =>
                                member.username.toLowerCase().contains(
                                  _query,
                                ) ||
                                member.displayName.toLowerCase().contains(
                                  _query,
                                ),
                          );
                    })
                    .toList(growable: false);
                if (filtered.isEmpty) {
                  return AppEmptyState(
                    icon: _archived
                        ? Icons.archive_outlined
                        : Icons.forum_outlined,
                    title: _query.isNotEmpty
                        ? 'No matching conversations'
                        : _archived
                        ? 'No archived conversations'
                        : 'No conversations yet',
                    message: _query.isNotEmpty
                        ? 'Try another name or username.'
                        : 'Message an athlete, trainer, teammate, or create a group.',
                    actionLabel: _query.isEmpty && !_archived
                        ? 'Start a conversation'
                        : null,
                    onAction: _query.isEmpty && !_archived
                        ? () => context.go(AppRoutes.newConversation)
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(messagingInboxProvider(_archived));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.sm,
                      AppSpacing.xxl,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final ConversationSummary conversation = filtered[index];
                      return ConversationTile(
                        conversation: conversation,
                        onTap: () {
                          if (conversation.isSportsGroupChannel &&
                              conversation.sportsGroupId != null &&
                              conversation.sportsChannelType != null &&
                              conversation.sportsChannelType!.isNotEmpty) {
                            context.go(
                              AppRoutes.groupChannel(
                                conversation.sportsGroupId!,
                                conversation.sportsChannelType!,
                              ),
                            );
                            return;
                          }
                          context.go(AppRoutes.conversation(conversation.id));
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, _) => _MessagesError(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(messagingInboxProvider(_archived)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.newConversation),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Message'),
      ),
    );
  }
}

class _MessagesError extends StatelessWidget {
  const _MessagesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Messages could not be loaded',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
