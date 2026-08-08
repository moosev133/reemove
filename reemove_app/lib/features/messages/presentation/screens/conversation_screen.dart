import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/result/result.dart';
import '../../../../core/debug/staging_diagnostics.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../feed/application/feed_providers.dart';
import '../../../groups/application/groups_providers.dart';
import '../../../groups/application/sports_group_channel_context_resolver.dart';
import '../../../groups/domain/entities/group.dart';
import '../../../groups/domain/entities/group_channel.dart';
import '../../../groups/domain/entities/group_enums.dart';
import '../../../groups/domain/entities/sports_group_channel_context.dart';
import '../../../feed/domain/entities/content_report.dart';
import '../../../feed/presentation/widgets/content_report_reason_sheet.dart';
import '../../../marketplace/presentation/widgets/marketplace_conversation_banner.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/messaging_providers.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_attachment_draft.dart';
import '../../domain/entities/messaging_presence.dart';
import '../../domain/repositories/messaging_presence_repository.dart';
import '../conversation_message_action_policy.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';
import '../widgets/presence_badge.dart';
import '../widgets/typing_indicator.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    required this.conversationId,
    this.marketplaceListingId,
    this.sportsGroupContext,
    super.key,
  });

  final String conversationId;
  final String? marketplaceListingId;
  final SportsGroupChannelContext? sportsGroupContext;

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
  GroupMediaMode _mediaMode = GroupMediaMode.normal;
  bool _didFocusMessage = false;
  MessagingPresenceRepository? _presenceRepository;

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
    final MessagingPresenceRepository? presence = _presenceRepository;
    if (uid != null && presence != null) {
      unawaited(
        presence.setTyping(
          conversationId: widget.conversationId,
          userId: uid,
          isTyping: false,
        ),
      );
      unawaited(
        presence.leaveConversation(
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
    final MessagingPresenceRepository presence = ref.read(
      messagingPresenceRepositoryProvider,
    );
    _presenceRepository = presence;
    await presence.joinConversation(
      conversationId: widget.conversationId,
      userId: user.uid,
    );
  }

  SportsGroupChannelContext? _resolveSportsContext(
    Conversation? conversation, {
    Group? watchedGroup,
    List<GroupChannel>? watchedChannels,
    String? viewerUid,
  }) {
    final String? resolvedViewerUid = viewerUid ??
        _userId ??
        ref.read(currentAuthUserProvider).value?.uid;
    final String? groupId = SportsGroupChannelContextResolver.resolvedGroupId(
      navigationContext: widget.sportsGroupContext,
      conversation: conversation,
    );
    final Group? group = watchedGroup ??
        (groupId == null
            ? null
            : ref.read(groupProvider(groupId)).value);
    final List<GroupChannel> channels = watchedChannels ??
        (groupId == null
            ? const <GroupChannel>[]
            : ref.read(groupChannelsProvider(groupId)).value ??
                const <GroupChannel>[]);
    final GroupChannelType channelType =
        SportsGroupChannelContextResolver.resolvedChannelType(
          navigationContext: widget.sportsGroupContext,
          conversation: conversation,
        );
    GroupChannel? channel;
    for (final GroupChannel item in channels) {
      if (item.type == channelType) {
        channel = item;
        break;
      }
    }
    return SportsGroupChannelContextResolver.resolve(
      navigationContext: widget.sportsGroupContext,
      conversation: conversation,
      group: group,
      channel: channel,
      viewerUid: resolvedViewerUid,
    );
  }

  Future<String?> _resolveViewerUid() async {
    if (_userId != null && _userId!.isNotEmpty) {
      return _userId;
    }
    final AuthUser? cached = ref.read(currentAuthUserProvider).value;
    if (cached != null) {
      _userId = cached.uid;
      return cached.uid;
    }
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user != null && mounted) {
      _userId = user.uid;
    }
    return user?.uid;
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
        final String? resolvedGroupId =
            SportsGroupChannelContextResolver.resolvedGroupId(
              navigationContext: widget.sportsGroupContext,
              conversation: conversation,
            );
        Group? watchedGroup;
        List<GroupChannel>? watchedChannels;
        if (resolvedGroupId != null) {
          watchedGroup = ref.watch(groupProvider(resolvedGroupId)).value;
          watchedChannels = ref.watch(groupChannelsProvider(resolvedGroupId)).value;
        }
        final String? viewerUid =
            _userId ?? ref.watch(currentAuthUserProvider).value?.uid;
        final SportsGroupChannelContext? sports = _resolveSportsContext(
          conversation,
          watchedGroup: watchedGroup,
          watchedChannels: watchedChannels,
          viewerUid: viewerUid,
        );
        final bool canPublish = sports?.canPublish ?? true;
        final bool canReply = canPublish || sports == null;
        final String? focusMessageId = sports?.focusMessageId;
        final String title = sports == null
            ? conversation.title
            : '${sports.groupName} · ${sports.channelType.displayLabel}';
        final AsyncValue<List<ConnectivityResult>> connectivity = ref.watch(
          connectivityResultsProvider,
        );
        final bool offline =
            connectivity.value?.contains(ConnectivityResult.none) ?? false;
        if (focusMessageId != null &&
            focusMessageId.isNotEmpty &&
            !_didFocusMessage &&
            all.any((ConversationMessage m) => m.id == focusMessageId)) {
          _didFocusMessage = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) {
              return;
            }
            final int focusIndex = all.indexWhere(
              (ConversationMessage m) => m.id == focusMessageId,
            );
            if (focusIndex < 0) {
              return;
            }
            final double offset = (focusIndex * 96.0).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
            unawaited(
              _scrollController.animateTo(
                offset,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
              ),
            );
          });
        }
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: sports != null
                  ? () => context.push(AppRoutes.groupChannels(sports.groupId))
                  : () => context.go(
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            sports != null
                                ? (canPublish
                                      ? 'Group channel'
                                      : 'Announcements · read only')
                                : conversation.isGroup
                                ? '${conversation.memberCount} members'
                                : presence == MessagingPresenceState.online
                                ? 'Online'
                                : 'Tap for details',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    if (!conversation.isGroup && sports == null) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      PresenceBadge(state: presence),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              if (sports != null)
                IconButton(
                  tooltip: 'Group channels',
                  onPressed: () =>
                      context.push(AppRoutes.groupChannels(sports.groupId)),
                  icon: const Icon(Icons.forum_outlined),
                )
              else
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
              if (offline)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.wifi_off_rounded),
                    title: Text(
                      'You are offline. Sending may fail until you reconnect.',
                    ),
                  ),
                ),
              if (widget.marketplaceListingId != null)
                MarketplaceConversationBanner(
                  listingId: widget.marketplaceListingId!,
                ),
              if (sports != null &&
                  sports.channelType == GroupChannelType.announcements &&
                  !canPublish)
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.campaign_outlined),
                    title: Text(
                      'Only owners and admins can publish announcements.',
                    ),
                  ),
                ),
              Expanded(
                child: messagesValue.when(
                  data: (_) => all.isEmpty
                      ? _EmptyConversation(sports: sports)
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
                                (conversation.isGroup || sports != null) &&
                                (previous == null ||
                                    previous.sender.id != message.sender.id ||
                                    message.sentAt
                                            .difference(previous.sentAt)
                                            .inMinutes >
                                        5);
                            return MessageBubble(
                              message: message,
                              isMine: message.sender.id == viewerUid,
                              showSender: showSender,
                              sportsGroupId: sports?.groupId,
                              canReply: canReply,
                              highlighted:
                                  focusMessageId != null &&
                                  message.id == focusMessageId,
                              onReply: canReply
                                  ? () => setState(
                                      () => _reply = MessageReplyPreview(
                                        messageId: message.id,
                                        senderId: message.sender.id,
                                        senderDisplayName:
                                            message.sender.displayName,
                                        kind: message.kind,
                                        preview: message.preview,
                                      ),
                                    )
                                  : () {},
                              onReact: (String emoji) {
                                unawaited(
                                  ref
                                      .read(
                                        messagingActionControllerProvider
                                            .notifier,
                                      )
                                      .toggleReaction(
                                        conversationId: widget.conversationId,
                                        messageId: message.id,
                                        emoji: emoji,
                                      ),
                                );
                              },
                              onMore: () => _showMessageActions(message),
                              onOpenSenderProfile: () {
                                final String username = message.sender.username;
                                if (username.isEmpty) {
                                  return;
                                }
                                unawaited(
                                  context.push(
                                    AppRoutes.publicProfile(username),
                                  ),
                                );
                              },
                              statusLabel: message.sender.id == viewerUid
                                  ? _readStatus(conversation, message)
                                  : null,
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, _) => AppErrorView(
                    title: 'Messages unavailable',
                    message: error.toString(),
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(
                      recentMessagesProvider(widget.conversationId),
                    ),
                  ),
                ),
              ),
              TypingIndicator(names: typingNames),
              if (canPublish)
                MessageComposer(
                  controller: _textController,
                  drafts: _drafts,
                  isSending: sending,
                  reply: _reply,
                  uploadProgress: _uploadProgress,
                  mediaMode: sports == null ? null : _mediaMode,
                  supportedMediaModes: sports?.supportedMediaModes,
                  onMediaModeChanged: sports == null
                      ? null
                      : (GroupMediaMode mode) => setState(() {
                          _mediaMode = mode;
                          for (int i = 0; i < _drafts.length; i++) {
                            final MessageAttachmentDraft draft = _drafts[i];
                            _drafts[i] = MessageAttachmentDraft(
                              id: draft.id,
                              bytes: draft.bytes,
                              fileName: draft.fileName,
                              contentType: draft.contentType,
                              kind: draft.kind,
                              mediaMode: mode,
                            );
                          }
                        }),
                  onCancelReply: () => setState(() => _reply = null),
                  onChanged: _onTypingChanged,
                  onSend: _send,
                  onPickImage: () => _pickMedia(video: false),
                  onPickVideo: () => _pickMedia(video: true),
                  onRemoveDraft: (String id) {
                    setState(
                      () => _drafts.removeWhere((item) => item.id == id),
                    );
                  },
                )
              else
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'You can read announcements, but only owners and admins can post.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, _) => Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        body: AppErrorView(
          title: 'Conversation unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () =>
              ref.invalidate(conversationProvider(widget.conversationId)),
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
          setState(
            () => _drafts.add(
              MessageAttachmentDraft(
                id: draft.id,
                bytes: draft.bytes,
                fileName: draft.fileName,
                contentType: draft.contentType,
                kind: draft.kind,
                mediaMode: _resolveSportsContext(
                          ref
                              .read(conversationProvider(widget.conversationId))
                              .value,
                        ) ==
                        null
                    ? GroupMediaMode.normal
                    : _mediaMode,
              ),
            ),
          );
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
    final SportsGroupChannelContext? sports = _resolveSportsContext(
      ref.read(conversationProvider(widget.conversationId)).value,
    );
    final bool sent = await ref
        .read(messagingActionControllerProvider.notifier)
        .send(
          conversationId: widget.conversationId,
          text: text,
          drafts: List<MessageAttachmentDraft>.of(_drafts),
          replyToMessageId: _reply?.messageId,
          sportsGroupId: sports?.groupId,
          channelType: sports?.channelType.wireValue,
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
          action: SnackBarAction(label: 'Retry', onPressed: _send),
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
    final String? viewerUid = await _resolveViewerUid();
    final Conversation? conversation =
        ref.read(conversationProvider(widget.conversationId)).value;
    final String? resolvedGroupId =
        SportsGroupChannelContextResolver.resolvedGroupId(
          navigationContext: widget.sportsGroupContext,
          conversation: conversation,
        );
    final Group? watchedGroup = resolvedGroupId == null
        ? null
        : ref.read(groupProvider(resolvedGroupId)).value;
    final List<GroupChannel>? watchedChannels = resolvedGroupId == null
        ? null
        : ref.read(groupChannelsProvider(resolvedGroupId)).value;
    final SportsGroupChannelContext? sports = _resolveSportsContext(
      conversation,
      watchedGroup: watchedGroup,
      watchedChannels: watchedChannels,
      viewerUid: viewerUid,
    );
    final bool mine = message.sender.id == viewerUid;
    final bool canReply = sports == null || sports.canPublish;
    final bool showBlock =
        !mine && conversation != null && !conversation.isGroup;
    final bool canModerate = sports?.canModerate ?? false;
    final bool showOwnDelete = ConversationMessageActionPolicy.showDeleteOwn(
      isMine: mine,
      message: message,
    );
    final bool showModeratorDelete =
        ConversationMessageActionPolicy.showModeratorDelete(
          isMine: mine,
          message: message,
          canModerate: canModerate,
        );

    // Staging-only trace of permission propagation into the message action sheet.
    final String? navGroupId = widget.sportsGroupContext?.groupId;
    final bool navCanModerate = widget.sportsGroupContext?.canModerate ?? false;
    final String? sportsGroupId = sports?.groupId;
    final bool resolvedCanModerate = canModerate;
    final Group? resolvedGroup = sportsGroupId == null
        ? null
        : ref.read(groupProvider(sportsGroupId)).value;

    StagingDiagnostics.log(
      'MESSAGE_ACTION_MENU',
      <String, Object?>{
        'currentUserUid': _userId,
        'message.senderId': message.sender.id,
        'message.isDeleted': message.isDeleted,
        'conversationId': widget.conversationId,
        'group.id': sportsGroupId,
        'group.ownerId': resolvedGroup?.ownerId,
        'group.viewerRole': resolvedGroup?.viewerRole?.name,
        'group.membershipStatus': resolvedGroup?.membershipStatus.name,
        'group.isManager': resolvedGroup?.isManager,
        'navigationContext.null': widget.sportsGroupContext == null,
        'navigationContext.groupId': navGroupId,
        'navigationContext.canModerate': navCanModerate,
        'resolvedContext.null': sports == null,
        'SportsGroupChannelContext.canModerate': resolvedCanModerate,
        'policy.isOwnMessage': mine,
        'policy.canDeleteMessage': showOwnDelete || showModeratorDelete,
        'policy.canDeleteModerator': showModeratorDelete,
        'policy.canDeleteOwn': showOwnDelete,
        'conversation.memberRole': _userId == null
            ? null
            : conversation?.member(_userId!)?.role.name,
      },
    );

    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            if (canReply)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            if (ConversationMessageActionPolicy.showEdit(
              isMine: mine,
              message: message,
            ))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (showOwnDelete)
              ListTile(
                key: const Key('message-action-delete-own'),
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete message'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            if (showModeratorDelete)
              ListTile(
                key: const Key('message-action-delete-moderator'),
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Delete message'),
                subtitle: const Text('Remove for everyone (manager)'),
                onTap: () => Navigator.pop(context, 'moderate_delete'),
              ),
            if (ConversationMessageActionPolicy.showReport(
              isMine: mine,
              canModerate: canModerate,
            ))
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report message'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            if (showBlock)
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: Text('Block ${message.sender.displayName}'),
                onTap: () => Navigator.pop(context, 'block'),
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
    } else if (action == 'delete' || action == 'moderate_delete') {
      final bool isModeration = action == 'moderate_delete';
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(isModeration ? 'Remove message?' : 'Delete message?'),
          content: Text(
            isModeration
                ? 'This removes the message for everyone in the channel. '
                      'Replies will show “Message deleted”.'
                : 'This removes the message for everyone in the conversation.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isModeration ? 'Remove' : 'Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      final bool ok = await ref
          .read(messagingActionControllerProvider.notifier)
          .delete(conversationId: widget.conversationId, messageId: message.id);
      if (!mounted) {
        return;
      }
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isModeration ? 'Message removed.' : 'Message deleted.',
            ),
          ),
        );
      } else {
        final Object? error = ref.read(messagingActionControllerProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error?.toString() ?? 'Could not delete this message.',
            ),
          ),
        );
      }
    } else if (action == 'report') {
      final ContentReportReason? reason = await showContentReportReasonSheet(
        context,
        title: 'Why are you reporting this message?',
      );
      if (!mounted || reason == null) {
        return;
      }
      await ref
          .read(messagingActionControllerProvider.notifier)
          .report(
            conversationId: widget.conversationId,
            messageId: message.id,
            reason: reason.name,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted for review.')),
        );
      }
    } else if (action == 'block') {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Block ${message.sender.displayName}?'),
          content: const Text(
            'They will no longer be able to message you or see your profile.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      final bool blocked = await ref
          .read(profileActionControllerProvider.notifier)
          .block(message.sender.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked
                ? '${message.sender.displayName} was blocked.'
                : 'Could not block this profile.',
          ),
        ),
      );
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
  const _EmptyConversation({this.sports});

  final SportsGroupChannelContext? sports;

  @override
  Widget build(BuildContext context) {
    final String title = sports == null
        ? 'No messages yet'
        : sports!.channelType == GroupChannelType.announcements
        ? 'No announcements yet'
        : 'Start the conversation';
    final String message = sports == null
        ? 'Say hello or share a photo to begin.'
        : sports!.channelType == GroupChannelType.announcements
        ? (sports!.canPublish
              ? 'Publish the first announcement for this group.'
              : 'Owners and admins will post announcements here.')
        : 'Share updates with active group members.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              sports?.channelType == GroupChannelType.announcements
                  ? Icons.campaign_outlined
                  : Icons.chat_bubble_outline_rounded,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
