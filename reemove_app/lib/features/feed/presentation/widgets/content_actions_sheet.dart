import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../application/feed_providers.dart';
import '../../domain/entities/content_report.dart';
import 'content_report_reason_sheet.dart';

Future<void> showPostActions(
  BuildContext context, {
  required String postId,
  required String authorId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) =>
        _PostActionsSheet(postId: postId, authorId: authorId),
  );
}

class _PostActionsSheet extends ConsumerStatefulWidget {
  const _PostActionsSheet({required this.postId, required this.authorId});

  final String postId;
  final String authorId;

  @override
  ConsumerState<_PostActionsSheet> createState() => _PostActionsSheetState();
}

class _PostActionsSheetState extends ConsumerState<_PostActionsSheet> {
  bool _busy = false;

  Future<void> _report() async {
    final ContentReportReason? reason = await showContentReportReasonSheet(
      context,
      title: 'Why are you reporting this post?',
    );
    if (reason == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    final Result<void> result = await ref
        .read(postInteractionRepositoryProvider)
        .report(
          ContentReportRequest(
            targetType: 'post',
            targetId: widget.postId,
            reason: reason,
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    result.when<void>(
      success: (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted for review.')),
        );
      },
      failure: _showFailure,
    );
  }

  Future<void> _block() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Block this account?'),
            content: const Text(
              'You will stop seeing each other’s content and they will not be notified.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Block'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    final Result<void> result = await ref
        .read(postInteractionRepositoryProvider)
        .blockUser(widget.authorId);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    result.when<void>(
      success: (_) {
        ref.invalidate(feedControllerProvider);
        ref.invalidate(storyRailProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account blocked.')));
      },
      failure: _showFailure,
    );
  }

  void _showFailure(Failure failure) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_busy) const LinearProgressIndicator(),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report post'),
              subtitle: const Text('Send this content to the safety team.'),
              enabled: !_busy,
              onTap: _report,
            ),
            ListTile(
              leading: Icon(
                Icons.block_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Block account'),
              subtitle: const Text(
                'Hide this account and prevent interactions.',
              ),
              enabled: !_busy,
              onTap: _block,
            ),
          ],
        ),
      ),
    );
  }
}
