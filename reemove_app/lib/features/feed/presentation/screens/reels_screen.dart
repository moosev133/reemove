import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../application/feed_providers.dart';
import '../../domain/entities/feed_page.dart';
import '../../domain/entities/feed_post.dart';
import '../../domain/repositories/post_interaction_repository.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/content_actions_sheet.dart';
import '../widgets/inline_video_player.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final PageController _controller = PageController();
  List<FeedPost> _items = const <FeedPost>[];
  FeedCursor? _cursor;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append && (_loadingMore || !_hasMore)) {
      return;
    }
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null) {
      return;
    }
    final Result<FeedPage> result = await ref
        .read(feedRepositoryProvider)
        .loadReels(viewerId: user.uid, cursor: append ? _cursor : null);
    result.when<void>(
      success: (FeedPage page) {
        if (!mounted) {
          return;
        }
        final Map<String, FeedPost> merged = <String, FeedPost>{
          if (append)
            for (final FeedPost item in _items) item.id: item,
          for (final FeedPost item in page.items) item.id: item,
        };
        setState(() {
          _items = merged.values.toList(growable: false);
          _cursor = page.nextCursor;
          _hasMore = page.hasMore;
          _loading = false;
          _loadingMore = false;
        });
      },
      failure: (failure) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = failure.message;
          _loading = false;
          _loadingMore = false;
        });
      },
    );
  }

  Future<void> _toggle(FeedPost post, PostReactionType type) async {
    final Result<ReactionMutationResult> result = await ref
        .read(postInteractionRepositoryProvider)
        .togglePostReaction(postId: post.id, type: type);
    result.when<void>(
      success: (ReactionMutationResult value) {
        final int index = _items.indexWhere(
          (FeedPost item) => item.id == post.id,
        );
        if (index < 0 || !mounted) {
          return;
        }
        final FeedPost current = _items[index];
        final FeedPost updated = switch (type) {
          PostReactionType.like => current.copyWith(
            likeCount: value.count,
            viewerState: current.viewerState.copyWith(isLiked: value.active),
          ),
          PostReactionType.save => current.copyWith(
            saveCount: value.count,
            viewerState: current.viewerState.copyWith(isSaved: value.active),
          ),
          PostReactionType.repost => current.copyWith(
            repostCount: value.count,
            viewerState: current.viewerState.copyWith(isReposted: value.active),
          ),
        };
        setState(() {
          _items = List<FeedPost>.of(_items)..[index] = updated;
        });
      },
      failure: (failure) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Reels'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Create reel',
            onPressed: () => context.push(AppRoutes.createFlow('reel')),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _error != null && _items.isEmpty
          ? AppEmptyState(
              icon: Icons.video_file_outlined,
              title: 'Reels could not load',
              message: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : _items.isEmpty
          ? AppEmptyState(
              icon: Icons.video_collection_outlined,
              title: 'No reels yet',
              message: 'Share the first short sports video.',
              actionLabel: 'Create reel',
              onAction: () => context.push(AppRoutes.createFlow('reel')),
            )
          : PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: _items.length,
              onPageChanged: (int index) {
                setState(() => _activeIndex = index);
                unawaited(
                  ref
                      .read(feedControllerProvider.notifier)
                      .recordView(_items[index].id),
                );
                if (index >= _items.length - 3) {
                  unawaited(_load(append: true));
                }
              },
              itemBuilder: (BuildContext context, int index) {
                final FeedPost post = _items[index];
                return _ReelPage(
                  post: post,
                  isActive: _activeIndex == index,
                  loadingMore: _loadingMore && index == _items.length - 1,
                  onLike: () => _toggle(post, PostReactionType.like),
                  onSave: () => _toggle(post, PostReactionType.save),
                  onRepost: () => _toggle(post, PostReactionType.repost),
                  onComments: () => showPostComments(context, postId: post.id),
                  onMore: () => showPostActions(
                    context,
                    postId: post.id,
                    authorId: post.author.id,
                  ),
                  onAuthor: () => context.push(
                    AppRoutes.publicProfile(post.author.username),
                  ),
                );
              },
            ),
    );
  }
}

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    required this.post,
    required this.isActive,
    required this.loadingMore,
    required this.onLike,
    required this.onSave,
    required this.onRepost,
    required this.onComments,
    required this.onMore,
    required this.onAuthor,
  });

  final FeedPost post;
  final bool isActive;
  final bool loadingMore;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onRepost;
  final VoidCallback onComments;
  final VoidCallback onMore;
  final VoidCallback onAuthor;

  @override
  Widget build(BuildContext context) {
    final media = post.media.first;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (media.downloadUrl != null)
          InlineVideoPlayer(
            url: media.downloadUrl!,
            thumbnailUrl: media.thumbnailUrl,
            autoPlay: isActive,
            loop: true,
            fit: BoxFit.contain,
          )
        else
          const Center(
            child: Text(
              'Video is processing',
              style: TextStyle(color: Colors.white),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x66000000),
                Colors.transparent,
                Color(0xCC000000),
              ],
              stops: <double>[0, .48, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              72,
              AppSpacing.sm,
              AppSpacing.lg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      InkWell(
                        onTap: onAuthor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AppAvatar(
                              displayName: post.author.displayName,
                              imageUrl: post.author.avatarUrl,
                              radius: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                '@${post.author.username}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (post.author.isVerified) ...<Widget>[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                color: Colors.lightBlueAccent,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (post.caption.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          post.caption,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                      if (post.sportId != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Chip(
                          avatar: const Icon(Icons.sports_rounded, size: 18),
                          label: Text(post.sportId!),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    _ReelAction(
                      icon: post.viewerState.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${post.likeCount}',
                      active: post.viewerState.isLiked,
                      onTap: onLike,
                    ),
                    _ReelAction(
                      icon: Icons.mode_comment_outlined,
                      label: '${post.commentCount}',
                      onTap: onComments,
                    ),
                    _ReelAction(
                      icon: Icons.repeat_rounded,
                      label: '${post.repostCount}',
                      active: post.viewerState.isReposted,
                      onTap: onRepost,
                    ),
                    _ReelAction(
                      icon: post.viewerState.isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: 'Save',
                      active: post.viewerState.isSaved,
                      onTap: onSave,
                    ),
                    _ReelAction(
                      icon: Icons.more_horiz_rounded,
                      label: 'More',
                      onTap: onMore,
                    ),
                    if (loadingMore)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: CircularProgressIndicator.adaptive(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          IconButton.filledTonal(
            onPressed: onTap,
            icon: Icon(icon, color: active ? Colors.redAccent : Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: .35),
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
