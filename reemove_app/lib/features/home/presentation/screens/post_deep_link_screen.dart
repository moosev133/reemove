import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../feed/application/feed_providers.dart';
import '../../../feed/domain/entities/feed_post.dart';
import '../../../feed/domain/repositories/post_interaction_repository.dart';
import '../../../feed/presentation/widgets/comments_bottom_sheet.dart';
import '../../../feed/presentation/widgets/content_actions_sheet.dart';
import '../../../feed/presentation/widgets/feed_post_card.dart';

class PostDeepLinkScreen extends ConsumerWidget {
  const PostDeepLinkScreen({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FeedPost?> post = ref.watch(postByIdProvider(postId));
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: post.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (_, _) => AppEmptyState(
          icon: Icons.hide_image_outlined,
          title: 'This post is unavailable',
          message:
              'It may have been removed, made private, or shared with a different audience.',
          actionLabel: 'Return home',
          onAction: () => context.go(AppRoutes.home),
        ),
        data: (FeedPost? value) {
          if (value == null) {
            return AppEmptyState(
              icon: Icons.hide_image_outlined,
              title: 'This post is unavailable',
              message: 'It may have been removed or made private.',
              actionLabel: 'Return home',
              onAction: () => context.go(AppRoutes.home),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: FeedPostCard(
                  post: value,
                  onLike: () => _toggle(ref, value, PostReactionType.like),
                  onSave: () => _toggle(ref, value, PostReactionType.save),
                  onRepost: () => _toggle(ref, value, PostReactionType.repost),
                  onComments: () => showPostComments(context, postId: value.id),
                  onMore: () => showPostActions(
                    context,
                    postId: value.id,
                    authorId: value.author.id,
                  ),
                  onAuthor: () => context.push(
                    AppRoutes.publicProfile(value.author.username),
                  ),
                  onOpen: () {},
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggle(
    WidgetRef ref,
    FeedPost post,
    PostReactionType type,
  ) async {
    await ref
        .read(postInteractionRepositoryProvider)
        .togglePostReaction(postId: post.id, type: type);
    ref.invalidate(postByIdProvider(post.id));
    ref.invalidate(feedControllerProvider);
  }
}
