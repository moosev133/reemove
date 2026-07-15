import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../application/messaging_providers.dart';
import '../../domain/entities/message.dart';

class MessageAttachmentView extends ConsumerWidget {
  const MessageAttachmentView({required this.attachment, super.key});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachment.processingState == AttachmentProcessingState.processing) {
      return const _AttachmentStatus(
        icon: Icons.hourglass_top_rounded,
        label: 'Processing media…',
      );
    }
    if (attachment.processingState == AttachmentProcessingState.failed) {
      return const _AttachmentStatus(
        icon: Icons.error_outline_rounded,
        label: 'Media processing failed',
      );
    }
    final String? direct = attachment.downloadUrl;
    if (direct != null && direct.isNotEmpty) {
      return _ReadyAttachment(attachment: attachment, url: direct);
    }
    final AsyncValue<String> url = ref.watch(
      attachmentDownloadUrlProvider(attachment.storagePath),
    );
    return url.when(
      data: (String value) =>
          _ReadyAttachment(attachment: attachment, url: value),
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _AttachmentStatus(
        icon: Icons.broken_image_outlined,
        label: 'Media unavailable',
      ),
    );
  }
}

class _ReadyAttachment extends StatelessWidget {
  const _ReadyAttachment({required this.attachment, required this.url});

  final MessageAttachment attachment;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: switch (attachment.kind) {
        MessageKind.image => Image.network(
          url,
          width: 260,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _AttachmentStatus(
            icon: Icons.broken_image_outlined,
            label: 'Image unavailable',
          ),
        ),
        MessageKind.video => Container(
          width: 260,
          height: 160,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.play_circle_fill_rounded, size: 52),
              SizedBox(height: AppSpacing.xs),
              Text('Video attachment'),
            ],
          ),
        ),
        MessageKind.audio => Container(
          width: 260,
          padding: const EdgeInsets.all(AppSpacing.md),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Row(
            children: <Widget>[
              Icon(Icons.play_arrow_rounded),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Audio message')),
            ],
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _AttachmentStatus extends StatelessWidget {
  const _AttachmentStatus({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon),
          const SizedBox(height: AppSpacing.xs),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
