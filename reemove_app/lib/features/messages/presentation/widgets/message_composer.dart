import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_attachment_draft.dart';

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.controller,
    required this.drafts,
    required this.isSending,
    required this.onChanged,
    required this.onSend,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onRemoveDraft,
    super.key,
    this.reply,
    this.onCancelReply,
    this.uploadProgress,
  });

  final TextEditingController controller;
  final List<MessageAttachmentDraft> drafts;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final ValueChanged<String> onRemoveDraft;
  final MessageReplyPreview? reply;
  final VoidCallback? onCancelReply;
  final double? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        color: colors.surface,
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (reply != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.reply_rounded, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Replying to ${reply!.senderDisplayName}: ${reply!.preview}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel reply',
                        visualDensity: VisualDensity.compact,
                        onPressed: onCancelReply,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              if (drafts.isNotEmpty)
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: drafts.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (BuildContext context, int index) {
                      final MessageAttachmentDraft draft = drafts[index];
                      return InputChip(
                        avatar: Icon(
                          draft.kind == MessageKind.image
                              ? Icons.image_outlined
                              : Icons.videocam_outlined,
                        ),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            draft.fileName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onDeleted: isSending
                            ? null
                            : () => onRemoveDraft(draft.id),
                      );
                    },
                  ),
                ),
              if (uploadProgress != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: LinearProgressIndicator(value: uploadProgress),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  MenuAnchor(
                    builder:
                        (
                          BuildContext context,
                          MenuController menu,
                          Widget? child,
                        ) {
                          return IconButton.filledTonal(
                            tooltip: 'Add attachment',
                            onPressed: isSending
                                ? null
                                : () =>
                                      menu.isOpen ? menu.close() : menu.open(),
                            icon: const Icon(Icons.add_rounded),
                          );
                        },
                    menuChildren: <Widget>[
                      MenuItemButton(
                        onPressed: onPickImage,
                        leadingIcon: const Icon(Icons.image_outlined),
                        child: const Text('Photo'),
                      ),
                      MenuItemButton(
                        onPressed: onPickVideo,
                        leadingIcon: const Icon(Icons.videocam_outlined),
                        child: const Text('Video'),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      enabled: !isSending,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: isSending ? null : onSend,
                    icon: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
