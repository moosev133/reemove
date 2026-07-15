import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../application/feed_providers.dart';
import '../../domain/entities/post_comment.dart';
import '../../domain/repositories/post_interaction_repository.dart';
import 'relative_time.dart';

Future<void> showPostComments(BuildContext context, {required String postId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _CommentsSheet(postId: postId),
    ),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId});

  final String postId;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PostComment> _comments = const <PostComment>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _hasMore = false;
  DateTime? _cursorCreatedAt;
  String? _cursorDocumentId;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _loadingMore)) {
      return;
    }
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
      _failure = null;
    });
    final Result<CommentPage> result = await ref
        .read(postInteractionRepositoryProvider)
        .loadComments(
          postId: widget.postId,
          cursorCreatedAt: more ? _cursorCreatedAt : null,
          cursorDocumentId: more ? _cursorDocumentId : null,
        );
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (CommentPage page) {
        final Map<String, PostComment> merged = <String, PostComment>{
          if (more)
            for (final PostComment comment in _comments) comment.id: comment,
          for (final PostComment comment in page.items) comment.id: comment,
        };
        setState(() {
          _comments = merged.values.toList(growable: false);
          _hasMore = page.hasMore;
          _cursorCreatedAt = page.cursorCreatedAt;
          _cursorDocumentId = page.cursorDocumentId;
          _loading = false;
          _loadingMore = false;
        });
      },
      failure: (Failure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
          _loadingMore = false;
        });
      },
    );
  }

  Future<void> _send() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() {
      _sending = true;
      _failure = null;
    });
    final Result<PostComment> result = await ref
        .read(postInteractionRepositoryProvider)
        .createComment(postId: widget.postId, text: text);
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (PostComment comment) {
        _controller.clear();
        _focusNode.unfocus();
        setState(() {
          _comments = <PostComment>[comment, ..._comments];
          _sending = false;
        });
      },
      failure: (Failure failure) {
        setState(() {
          _failure = failure;
          _sending = false;
        });
      },
    );
  }

  Future<void> _toggleLike(PostComment comment) async {
    final PostComment optimistic = comment.copyWith(
      isLiked: !comment.isLiked,
      likeCount: (comment.likeCount + (comment.isLiked ? -1 : 1))
          .clamp(0, 1 << 31)
          .toInt(),
    );
    _replace(optimistic);
    final Result<ReactionMutationResult> result = await ref
        .read(postInteractionRepositoryProvider)
        .toggleCommentLike(postId: widget.postId, commentId: comment.id);
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (ReactionMutationResult value) {
        _replace(
          optimistic.copyWith(isLiked: value.active, likeCount: value.count),
        );
      },
      failure: (Failure failure) {
        _replace(comment);
        setState(() => _failure = failure);
      },
    );
  }

  void _replace(PostComment replacement) {
    setState(() {
      _comments = _comments
          .map(
            (PostComment item) =>
                item.id == replacement.id ? replacement : item,
          )
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Text('Comments', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                tooltip: 'Close comments',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        if (_failure != null)
          MaterialBanner(
            content: Text(_failure!.message),
            actions: <Widget>[
              TextButton(
                onPressed: () => setState(() => _failure = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : _comments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.mode_comment_outlined,
                          size: 42,
                          color: colors.primary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Start the conversation',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Be supportive, relevant, and respectful.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: _comments.length + (_hasMore ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == _comments.length) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: _loadingMore
                              ? null
                              : () => _load(more: true),
                          icon: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: const Text('Load more comments'),
                        ),
                      );
                    }
                    final PostComment comment = _comments[index];
                    return _CommentTile(
                      comment: comment,
                      onLike: () => _toggleLike(comment),
                    );
                  },
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment…',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  tooltip: 'Post comment',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onLike});

  final PostComment comment;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppAvatar(
            displayName: comment.author.displayName,
            imageUrl: comment.author.avatarUrl,
            radius: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        comment.author.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    if (comment.author.isVerified) ...<Widget>[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                    ],
                    const SizedBox(width: 7),
                    Text(
                      relativeTime(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.isDeleted ? 'Comment removed' : comment.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: comment.isDeleted
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: comment.isDeleted
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            children: <Widget>[
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: comment.isLiked ? 'Unlike comment' : 'Like comment',
                onPressed: comment.isDeleted ? null : onLike,
                icon: Icon(
                  comment.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: comment.isLiked
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),
              if (comment.likeCount > 0)
                Text(
                  '${comment.likeCount}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
