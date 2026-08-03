import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/app_navigation_badges.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../feed/application/feed_providers.dart';
import '../../../feed/application/feed_view_state.dart';
import '../../../feed/domain/entities/feed_post.dart';
import '../../../feed/domain/repositories/post_interaction_repository.dart';
import '../../../feed/presentation/widgets/comments_bottom_sheet.dart';
import '../../../feed/presentation/widgets/content_actions_sheet.dart';
import '../../../feed/presentation/widgets/feed_loading_skeleton.dart';
import '../../../feed/presentation/widgets/feed_post_card.dart';
import '../../../feed/presentation/widgets/story_rail.dart';
import '../../../notifications/application/notification_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  bool get wantKeepAlive => true;

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 800) {
      unawaited(ref.read(feedControllerProvider.notifier).loadMore());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profile = ref.watch(currentUserProfileProvider).value;
    final AsyncValue<FeedViewState> feed = ref.watch(feedControllerProvider);
    final AsyncValue<List<ConnectivityResult>> connectivity = ref.watch(
      connectivityResultsProvider,
    );
    final bool offline =
        connectivity.value?.contains(ConnectivityResult.none) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReeMove'),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'Reels',
            onPressed: () => context.push(AppRoutes.reels),
            icon: const Icon(Icons.video_collection_outlined),
          ),
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) {
              final int unread =
                  ref.watch(notificationUnreadCountProvider).value ??
                  ref.watch(appNavigationBadgesProvider).activity;
              return IconButton(
                tooltip: 'Activity',
                onPressed: () => context.push(AppRoutes.activity),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.go(AppRoutes.profile),
              child: AppAvatar(
                displayName: profile?.displayName ?? 'Athlete',
                imageUrl: profile?.avatarUrl,
                radius: 18,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          key: const PageStorageKey<String>('home-feed-scroll'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            if (offline)
              SliverToBoxAdapter(
                child: MaterialBanner(
                  leading: const Icon(Icons.cloud_off_outlined),
                  content: const Text(
                    'You are offline. ReeMove is showing content saved on this device.',
                  ),
                  actions: const <Widget>[SizedBox.shrink()],
                ),
              ),
            const SliverToBoxAdapter(child: StoryRail()),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: feed.maybeWhen(
                      data: (FeedViewState state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SegmentedButton<FeedMode>(
                            segments: const <ButtonSegment<FeedMode>>[
                              ButtonSegment<FeedMode>(
                                value: FeedMode.forYou,
                                label: Text('For you'),
                                icon: Icon(Icons.auto_awesome_rounded),
                              ),
                              ButtonSegment<FeedMode>(
                                value: FeedMode.following,
                                label: Text('Following'),
                                icon: Icon(Icons.people_alt_outlined),
                              ),
                            ],
                            selected: <FeedMode>{state.mode},
                            onSelectionChanged: (Set<FeedMode> selection) {
                              unawaited(
                                ref
                                    .read(feedControllerProvider.notifier)
                                    .selectMode(selection.first),
                              );
                            },
                          ),
                          if (state.fromCache) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Saved feed',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                          if (state.failure != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            MaterialBanner(
                              content: Text(state.failure!.message),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => ref
                                      .read(feedControllerProvider.notifier)
                                      .clearFailure(),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            ...feed.when(
              loading: () => <Widget>[
                const SliverToBoxAdapter(
                  child: _FeedWidth(child: FeedLoadingSkeleton()),
                ),
              ],
              error: (Object error, StackTrace _) => <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.sync_problem_rounded,
                    title: 'Your feed could not load',
                    message: error.toString(),
                    actionLabel: 'Try again',
                    onAction: () => ref.invalidate(feedControllerProvider),
                  ),
                ),
              ],
              data: (FeedViewState state) {
                if (state.items.isEmpty && !state.isRefreshing) {
                  return <Widget>[
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: state.mode == FeedMode.following
                            ? Icons.people_outline_rounded
                            : Icons.dynamic_feed_outlined,
                        title: state.mode == FeedMode.following
                            ? 'Your following feed is ready'
                            : 'No posts are available yet',
                        message: state.mode == FeedMode.following
                            ? 'Follow athletes and sports communities to build this feed.'
                            : 'Create the first sports moment or explore ReeMove.',
                        actionLabel: state.mode == FeedMode.following
                            ? 'Discover people'
                            : 'Create a post',
                        onAction: () => context.go(
                          state.mode == FeedMode.following
                              ? AppRoutes.discover
                              : AppRoutes.createFlow('post'),
                        ),
                      ),
                    ),
                  ];
                }
                return <Widget>[
                  SliverList.builder(
                    itemCount: state.items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final FeedPost post = state.items[index];
                      return _FeedWidth(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: FeedPostCard(
                            post: post,
                            onLike: () => ref
                                .read(feedControllerProvider.notifier)
                                .toggleReaction(post.id, PostReactionType.like),
                            onSave: () => ref
                                .read(feedControllerProvider.notifier)
                                .toggleReaction(post.id, PostReactionType.save),
                            onRepost: () => ref
                                .read(feedControllerProvider.notifier)
                                .toggleReaction(
                                  post.id,
                                  PostReactionType.repost,
                                ),
                            onComments: () => unawaited(
                              showPostComments(context, postId: post.id),
                            ),
                            onMore: () => unawaited(
                              showPostActions(
                                context,
                                postId: post.id,
                                authorId: post.author.id,
                              ),
                            ),
                            onAuthor: () => context.push(
                              AppRoutes.publicProfile(post.author.username),
                            ),
                            onOpen: () {
                              unawaited(
                                ref
                                    .read(feedControllerProvider.notifier)
                                    .recordView(post.id),
                              );
                              unawaited(
                                context.push(AppRoutes.homePost(post.id)),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  if (state.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ),
                  if (!state.hasMore && state.items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                        child: Center(
                          child: Text(
                            'You are all caught up.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedWidth extends StatelessWidget {
  const _FeedWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}
