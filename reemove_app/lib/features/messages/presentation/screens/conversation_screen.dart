import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../application/messaging_providers.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_attachment_draft.dart';
import '../../domain/entities/messaging_presence.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';
import '../widgets/presence_badge.dart';
import '../widgets/typing_indicator.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MessageAttachmentDraft> _drafts = <MessageAttachmentDraft>[];
  final List<ConversationMessage> _olderMessages = <ConversationMessage>[];
  Timer? _typingTimer;
  MessageReplyPreview? _reply;
  double? _uploadProgress;
  bool _loadingOlder = false;
  bool _hasMore = true;
  String? _userId;
  String? _lastMarkedMessageId;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_joinConversation));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    final String? uid = _userId;
    if (uid != null) {
      unawaited(
        ref
            .read(messagingPresenceRepositoryProvider)
            .setTyping(
              conversationId: widget.conversationId,
              userId: uid,
              isTyping: false,
            ),
      );
      unawaited(
        ref
            .read(messagingPresenceRepositoryProvider)
            .leaveConversation(
              conversationId: widget.conversationId,
              userId: uid,
            ),
      );
    }
    super.dispose();
  }

  Future<void> _joinConversation() async {
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null || !mounted) {
      return;
    }
    _userId = user.uid;
    await ref
        .read(messagingPresenceRepositoryProvider)
        .joinConversation(
          conversationId: widget.conversationId,
          userId: user.uid,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Conversation?> conversationValue = ref.watch(
      conversationProvider(widget.conversationId),
    );
    final AsyncValue<List<ConversationMessage>> messagesValue = ref.watch(
      recentMessagesProvider(widget.conversationId),
    );
    final bool sending = ref.watch(messagingActionControllerProvider).isLoading;

    return conversationValue.when(
      data: (Conversation? conversation) {
        if (conversation == null) {
          return _UnavailableConversation(
            conversationId: widget.conversationId,
          );
        }
        final List<ConversationMessage> recent =
            messagesValue.value ?? const <ConversationMessage>[];
        final List<ConversationMessage> all = _mergedMessages(recent);
        _scheduleRead(all);
        final List<String> typingNames = _typingNames(conversation);
        final MessagingPresenceState presence = _directPresence(conversation);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: () => context.go(
                AppRoutes.conversationDetails(widget.conversationId),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            conversation.isGroup
                                ? '${conversation.memberCount} members'
                                : presence == MessagingPresenceState.online
                                ? 'Online'
                                : 'Tap for details',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    if (!conversation.isGroup) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      PresenceBadge(state: presence),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Conversation details',
                onPressed: () => context.go(
                  AppRoutes.conversationDetails(widget.conversationId),
                ),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: messagesValue.when(
                  data: (_) => all.isEmpty
                      ? const _EmptyConversation()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(
                            top: AppSpacing.sm,
                            bottom: AppSpacing.md,
                          ),
                          itemCount: all.length + (_hasMore ? 1 : 0),
                          itemBuilder: (BuildContext context, int index) {
                            if (_hasMore && index == 0) {
                              return Center(
                                child: TextButton.icon(
                                  onPressed: _loadingOlder || all.isEmpty
                                      ? null
                                      : () => _loadOlder(all.first),
                                  icon: _loadingOlder
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.history_rounded),
                                  label: const Text('Load earlier messages'),
                                ),
                              );
                            }
                            final int messageIndex = index - (_hasMore ? 1 : 0);
                            final ConversationMessage message =
                                all[messageIndex];
                            final ConversationMessage? previous =
                                messageIndex > 0 ? all[messageIndex - 1] : null;
                            final bool showSender =
                                conversation.isGroup &&
                                (previous == null ||
                                    previous.sender.id != message.sender.id ||
                                    message.sentAt
                                            .difference(previous.sentAt)
                                            .inMinutes >
                                        5);
                            return MessageBubble(
                              message: message,
                              isMine: message.sender.id == _userId,
                              showSender: showSender,
                              onReply: () => setState(
                                () => _reply = MessageReplyPreview(
                                  messageId: message.id,
                                  senderId: message.sender.id,
                                  senderDisplayName: message.sender.displayName,
                                  kind: message.kind,
                                  preview: message.preview,
                                ),
                              ),
                              onReact: (String emoji) => ref
                                  .read(
                                    messagingActionControllerProvider.notifier,
                                  )
                                  .toggleReaction(
                                    conversationId: widget.conversationId,
                                    messageId: message.id,
                                    emoji: emoji,
                                  ),
                              onMore: () => _showMessageActions(message),
                              statusLabel: message.sender.id == _userId
                                  ? _readStatus(conversation, message)
                                  : null,
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              TypingIndicator(names: typingNames),
              MessageComposer(
                controller: _textController,
                drafts: _drafts,
                isSending: sending,
                reply: _reply,
                uploadProgress: _uploadProgress,
                onCancelReply: () => setState(() => _reply = null),
                onChanged: _onTypingChanged,
                onSend: _send,
                onPickImage: () => _pickMedia(video: false),
                onPickVideo: () => _pickMedia(video: true),
                onRemoveDraft: (String id) {
                  setState(() => _drafts.removeWhere((item) => item.id == id));
                },
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, _) => Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  List<ConversationMessage> _mergedMessages(List<ConversationMessage> recent) {
    final Map<String, ConversationMessage> unique =
        <String, ConversationMessage>{
          for (final ConversationMessage message in _olderMessages)
            message.id: message,
          for (final ConversationMessage message in recent) message.id: message,
        };
    final List<ConversationMessage> values =
        unique.values.toList(growable: false)..sort(
          (ConversationMessage a, ConversationMessage b) =>
              a.sentAt.compareTo(b.sentAt),
        );
    return values;
  }

  List<String> _typingNames(Conversation conversation) {
    final List<String> typingIds =
        ref
            .watch(conversationTypingProvider(widget.conversationId))
            .value
            ?.where((item) => item.userId != _userId)
            .map((item) => item.userId)
            .toList(growable: false) ??
        const <String>[];
    return conversation.members
        .where(
          (ConversationMember member) => typingIds.contains(member.user.id),
        )
        .map((ConversationMember member) => member.user.displayName)
        .toList(growable: false);
  }

  MessagingPresenceState _directPresence(Conversation conversation) {
    if (conversation.isGroup) {
      return MessagingPresenceState.offline;
    }
    final String? otherId = conversation.members
        .where((ConversationMember member) => member.user.id != _userId)
        .map((ConversationMember member) => member.user.id)
        .firstOrNull;
    if (otherId == null) {
      return MessagingPresenceState.offline;
    }
    return ref
            .watch(conversationPresenceProvider(widget.conversationId))
            .value?[otherId]
            ?.state ??
        MessagingPresenceState.offline;
  }

  String _readStatus(Conversation conversation, ConversationMessage message) {
    final bool read = conversation.members.any(
      (ConversationMember member) =>
          member.user.id != _userId &&
          member.lastReadAt != null &&
          !member.lastReadAt!.isBefore(message.sentAt),
    );
    return read ? 'Read' : 'Sent';
  }

  void _scheduleRead(List<ConversationMessage> messages) {
    if (messages.isEmpty) {
      return;
    }
    final ConversationMessage last = messages.last;
    if (last.id == _lastMarkedMessageId || last.sender.id == _userId) {
      return;
    }
    _lastMarkedMessageId = last.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(messagingActionControllerProvider.notifier).markRead(last),
        );
      }
    });
  }

  void _onTypingChanged(String value) {
    final bool typing = value.trim().isNotEmpty;
    unawaited(
      ref
          .read(messagingActionControllerProvider.notifier)
          .setTyping(conversationId: widget.conversationId, isTyping: typing),
    );
    _typingTimer?.cancel();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 4), () {
        unawaited(
          ref
              .read(messagingActionControllerProvider.notifier)
              .setTyping(
                conversationId: widget.conversationId,
                isTyping: false,
              ),
        );
      });
    }
  }

  Future<void> _pickMedia({required bool video}) async {
    final Result<MessageAttachmentDraft?> result = video
        ? await ref.read(messagingMediaPickerProvider).pickVideo()
        : await ref.read(messagingMediaPickerProvider).pickImage();
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (MessageAttachmentDraft? draft) {
        if (draft != null) {
          setState(() => _drafts.add(draft));
        }
      },
      failure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _send() async {
    final String text = _textController.text.trim();
    if (text.isEmpty && _drafts.isEmpty) {
      return;
    }
    final bool sent = await ref
        .read(messagingActionControllerProvider.notifier)
        .send(
          conversationId: widget.conversationId,
          text: text,
          drafts: List<MessageAttachmentDraft>.of(_drafts),
          replyToMessageId: _reply?.messageId,
          onProgress: (double progress) {
            if (mounted) {
              setState(() => _uploadProgress = progress);
            }
          },
        );
    if (!mounted) {
      return;
    }
    setState(() => _uploadProgress = null);
    if (sent) {
      _textController.clear();
      _drafts.clear();
      _reply = null;
      unawaited(
        ref
            .read(messagingActionControllerProvider.notifier)
            .setTyping(conversationId: widget.conversationId, isTyping: false),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          unawaited(
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
            ),
          );
        }
      });
    } else {
      final Object? error = ref.read(messagingActionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? 'Message could not be sent.'),
        ),
      );
    }
  }

  Future<void> _loadOlder(ConversationMessage oldest) async {
    if (_loadingOlder || !_hasMore || _userId == null) {
      return;
    }
    setState(() => _loadingOlder = true);
    final Result<MessagePage> result = await ref
        .read(messagingRepositoryProvider)
        .loadOlderMessages(
          conversationId: widget.conversationId,
          viewerId: _userId!,
          cursor: MessageCursor(sentAt: oldest.sentAt, documentId: oldest.id),
        );
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (MessagePage page) {
        setState(() {
          _olderMessages.addAll(page.items);
          _hasMore = page.hasMore;
          _loadingOlder = false;
        });
      },
      failure: (failure) {
        setState(() => _loadingOlder = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _showMessageActions(ConversationMessage message) async {
    final bool mine = message.sender.id == _userId;
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            if (mine && !message.isDeleted && message.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (mine && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete message'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report message'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'reply') {
      setState(
        () => _reply = MessageReplyPreview(
          messageId: message.id,
          senderId: message.sender.id,
          senderDisplayName: message.sender.displayName,
          kind: message.kind,
          preview: message.preview,
        ),
      );
    } else if (action == 'edit') {
      await _editMessage(message);
    } else if (action == 'delete') {
      await ref
          .read(messagingActionControllerProvider.notifier)
          .delete(conversationId: widget.conversationId, messageId: message.id);
    } else if (action == 'report') {
      await ref
          .read(messagingActionControllerProvider.notifier)
          .report(
            conversationId: widget.conversationId,
            messageId: message.id,
            reason: 'other',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted for review.')),
        );
      }
    }
  }

  Future<void> _editMessage(ConversationMessage message) async {
    final TextEditingController controller = TextEditingController(
      text: message.text,
    );
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 4000,
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
    if (value == null || value.isEmpty) {
      return;
    }
    await ref
        .read(messagingActionControllerProvider.notifier)
        .edit(
          conversationId: widget.conversationId,
          messageId: message.id,
          text: value,
        );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.sports_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Start the conversation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Plan a workout, match, route, or simply say hello.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableConversation extends StatelessWidget {
  const _UnavailableConversation({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline_rounded, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Conversation unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'It may no longer exist, or your account no longer has access. Reference: $conversationId',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
