import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../domain/entities/message.dart';
import 'message_attachment_view.dart';
import 'reply_preview.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSender,
    required this.onReply,
    required this.onReact,
    required this.onMore,
    super.key,
    this.statusLabel,
    this.sportsGroupId,
    this.canReply = true,
    this.highlighted = false,
    this.onOpenSenderProfile,
  });

  final ConversationMessage message;
  final bool isMine;
  final bool showSender;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;
  final VoidCallback onMore;
  final String? statusLabel;
  final String? sportsGroupId;
  final bool canReply;
  final bool highlighted;
  final VoidCallback? onOpenSenderProfile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = isMine
        ? colors.primaryContainer
        : colors.surfaceContainerHigh;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isMine) ...<Widget>[
            if (showSender)
              AppAvatar(
                displayName: message.sender.displayName,
                imageUrl: message.sender.avatarUrl,
                radius: 16,
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onMore,
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  if (showSender && !isMine)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.sm,
                        bottom: AppSpacing.xxs,
                      ),
                      child: Text(
                        message.sender.displayName,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppRadius.md),
                        topRight: const Radius.circular(AppRadius.md),
                        bottomLeft: Radius.circular(isMine ? AppRadius.md : 4),
                        bottomRight: Radius.circular(isMine ? 4 : AppRadius.md),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (message.replyTo != null) ...<Widget>[
                          ReplyPreview(reply: message.replyTo!),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        for (final MessageAttachment attachment
                            in message.attachments) ...<Widget>[
                          MessageAttachmentView(attachment: attachment),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        if (message.text.isNotEmpty)
                          Text(
                            message.text,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontStyle: message.isDeleted
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                          ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _time(message.sentAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                            if (message.editedAt != null) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'edited',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                            if (statusLabel != null) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                statusLabel!,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (message.reactionCounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Wrap(
                        spacing: AppSpacing.xxs,
                        children: message.reactionCounts.entries
                            .where(
                              (MapEntry<String, int> item) => item.value > 0,
                            )
                            .map(
                              (MapEntry<String, int> item) => ActionChip(
                                visualDensity: VisualDensity.compact,
                                label: Text('${item.key} ${item.value}'),
                                onPressed: () => onReact(item.key),
                                side: message.viewerReactions.contains(item.key)
                                    ? BorderSide(color: colors.primary)
                                    : null,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: onReply,
                        icon: const Icon(Icons.reply_rounded, size: 17),
                        label: const Text('Reply'),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'React',
                        icon: const Icon(Icons.add_reaction_outlined, size: 19),
                        onSelected: onReact,
                        itemBuilder: (_) => const <PopupMenuEntry<String>>[
                          PopupMenuItem(value: '👍', child: Text('👍  Like')),
                          PopupMenuItem(value: '🔥', child: Text('🔥  Fire')),
                          PopupMenuItem(value: '💪', child: Text('💪  Strong')),
                          PopupMenuItem(
                            value: '👏',
                            child: Text('👏  Applause'),
                          ),
                          PopupMenuItem(value: '❤️', child: Text('❤️  Love')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime value) {
    final TimeOfDay time = TimeOfDay.fromDateTime(value.toLocal());
    final String minute = time.minute.toString().padLeft(2, '0');
    return '${time.hour.toString().padLeft(2, '0')}:$minute';
  }
}
