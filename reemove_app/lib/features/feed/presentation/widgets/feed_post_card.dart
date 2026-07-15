import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../domain/entities/feed_post.dart';
import 'post_media_gallery.dart';
import 'relative_time.dart';

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onRepost,
    required this.onComments,
    required this.onMore,
    required this.onAuthor,
    required this.onOpen,
    super.key,
  });

  final FeedPost post;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onRepost;
  final VoidCallback onComments;
  final VoidCallback onMore;
  final VoidCallback onAuthor;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAuthor,
                    child: AppAvatar(
                      displayName: post.author.displayName,
                      imageUrl: post.author.avatarUrl,
                      radius: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
                      onTap: onAuthor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  post.author.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              if (post.author.isVerified) ...<Widget>[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: colors.primary,
                                  semanticLabel: 'Verified profile',
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _metadata(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More options',
                    onPressed: onMore,
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onOpen,
              child: PostMediaGallery(
                media: post.media,
                aspectRatio: post.kind == PostKind.reel ? 4 / 5 : 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: <Widget>[
                  _ActionButton(
                    tooltip: post.viewerState.isLiked ? 'Unlike' : 'Like',
                    icon: post.viewerState.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    selected: post.viewerState.isLiked,
                    count: post.likeCount,
                    onPressed: onLike,
                  ),
                  _ActionButton(
                    tooltip: 'Comments',
                    icon: Icons.mode_comment_outlined,
                    count: post.commentCount,
                    onPressed: onComments,
                  ),
                  _ActionButton(
                    tooltip: post.viewerState.isReposted
                        ? 'Remove repost'
                        : 'Repost',
                    icon: Icons.repeat_rounded,
                    selected: post.viewerState.isReposted,
                    count: post.repostCount,
                    onPressed: onRepost,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: post.viewerState.isSaved ? 'Remove save' : 'Save',
                    onPressed: onSave,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        post.viewerState.isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        key: ValueKey<bool>(post.viewerState.isSaved),
                        color: post.viewerState.isSaved ? colors.primary : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${post.author.username} ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: post.caption),
                    ],
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: TextButton(
                onPressed: onComments,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  post.commentCount == 0
                      ? 'Start the conversation'
                      : 'View ${_compactCount(post.commentCount)} comments',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _metadata() {
    final List<String> parts = <String>[
      '@${post.author.username}',
      relativeTime(post.publishedAt),
      if (post.sportId != null) post.sportId!,
      if (post.locationLabel != null) post.locationLabel!,
    ];
    return parts.join(' · ');
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.count,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final int count;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color? color = selected
        ? Theme.of(context).colorScheme.primary
        : null;
    return Semantics(
      button: true,
      label: '$tooltip, $count',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: <Widget>[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  icon,
                  key: ValueKey<String>('$icon-$selected'),
                  color: color,
                ),
              ),
              if (count > 0) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  _compactCount(count),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _compactCount(int count) {
  if (count < 1000) {
    return '$count';
  }
  if (count < 1000000) {
    final double value = count / 1000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}K';
  }
  final double value = count / 1000000;
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}M';
}
