import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/result/result.dart';
import '../../authentication/application/authentication_providers.dart';
import '../../authentication/domain/entities/auth_user.dart';
import '../data/repositories/firebase_content_publishing_repository.dart';
import '../data/repositories/firebase_feed_repository.dart';
import '../data/repositories/firebase_post_interaction_repository.dart';
import '../data/repositories/firebase_story_repository.dart';
import '../data/repositories/shared_preferences_content_draft_repository.dart';
import '../data/services/platform_content_media_picker.dart';
import '../domain/entities/feed_page.dart';
import '../domain/entities/feed_post.dart';
import '../domain/entities/story.dart';
import '../domain/repositories/content_draft_repository.dart';
import '../domain/repositories/content_publishing_repository.dart';
import '../domain/repositories/feed_repository.dart';
import '../domain/repositories/post_interaction_repository.dart';
import '../domain/repositories/story_repository.dart';
import '../domain/services/content_media_picker.dart';
import 'feed_view_state.dart';

final Provider<FeedRepository> feedRepositoryProvider =
    Provider<FeedRepository>((Ref ref) {
      final database = ref.watch(reeMoveFirestoreProvider);
      return FirebaseFeedRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        posts: database.posts,
        feedEntries: database.feedEntries,
        reactions: database.contentReactions,
      );
    });

final Provider<PostInteractionRepository> postInteractionRepositoryProvider =
    Provider<PostInteractionRepository>((Ref ref) {
      return FirebasePostInteractionRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
        auth: ref.watch(firebaseAuthProvider),
      );
    });

final Provider<StoryRepository> storyRepositoryProvider =
    Provider<StoryRepository>((Ref ref) {
      return FirebaseStoryRepository(
        functions: ref.watch(firebaseFunctionsProvider),
      );
    });

final Provider<ContentPublishingRepository>
contentPublishingRepositoryProvider = Provider<ContentPublishingRepository>((
  Ref ref,
) {
  final database = ref.watch(reeMoveFirestoreProvider);
  return FirebaseContentPublishingRepository(
    storage: ref.watch(firebaseStorageProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
    posts: database.posts,
    stories: database.stories,
  );
});

final Provider<ContentDraftRepository> contentDraftRepositoryProvider =
    Provider<ContentDraftRepository>((Ref ref) {
      return const SharedPreferencesContentDraftRepository();
    });

final Provider<ContentMediaPicker> contentMediaPickerProvider =
    Provider<ContentMediaPicker>((Ref ref) {
      return PlatformContentMediaPicker();
    });

final StreamProvider<List<ConnectivityResult>> connectivityResultsProvider =
    StreamProvider<List<ConnectivityResult>>((Ref ref) {
      return Connectivity().onConnectivityChanged;
    });

final AsyncNotifierProvider<FeedController, FeedViewState>
feedControllerProvider = AsyncNotifierProvider<FeedController, FeedViewState>(
  FeedController.new,
);

class FeedController extends AsyncNotifier<FeedViewState> {
  @override
  Future<FeedViewState> build() async {
    final String uid = await _requireUid();
    final Result<FeedPage> result = await ref
        .read(feedRepositoryProvider)
        .loadFeed(viewerId: uid, mode: FeedMode.forYou);
    return result.when<FeedViewState>(
      success: (FeedPage page) => FeedViewState.fromPage(FeedMode.forYou, page),
      failure: (Failure failure) => throw StateError(failure.message),
    );
  }

  Future<void> selectMode(FeedMode mode) async {
    final FeedViewState? current = state.value;
    if (current == null || current.mode == mode || current.isRefreshing) {
      return;
    }
    state = AsyncValue<FeedViewState>.data(
      current.copyWith(
        mode: mode,
        items: const <FeedPost>[],
        hasMore: true,
        clearCursor: true,
        isRefreshing: true,
        clearFailure: true,
      ),
    );
    await _replace(mode);
  }

  Future<void> refresh() async {
    final FeedViewState? current = state.value;
    if (current == null || current.isRefreshing) {
      return;
    }
    state = AsyncValue<FeedViewState>.data(
      current.copyWith(isRefreshing: true, clearFailure: true),
    );
    await _replace(current.mode);
    ref.invalidate(storyRailProvider);
  }

  Future<void> _replace(FeedMode mode) async {
    final String uid = await _requireUid();
    final Result<FeedPage> result = await ref
        .read(feedRepositoryProvider)
        .loadFeed(viewerId: uid, mode: mode);
    result.when<void>(
      success: (FeedPage page) {
        state = AsyncValue<FeedViewState>.data(
          FeedViewState.fromPage(mode, page),
        );
      },
      failure: (Failure failure) {
        final FeedViewState latest = state.requireValue;
        state = AsyncValue<FeedViewState>.data(
          latest.copyWith(isRefreshing: false, failure: failure),
        );
      },
    );
  }

  Future<void> loadMore() async {
    final FeedViewState? current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        current.isRefreshing ||
        !current.hasMore) {
      return;
    }
    state = AsyncValue<FeedViewState>.data(
      current.copyWith(isLoadingMore: true, clearFailure: true),
    );
    final String uid = await _requireUid();
    final Result<FeedPage> result = await ref
        .read(feedRepositoryProvider)
        .loadFeed(viewerId: uid, mode: current.mode, cursor: current.cursor);
    result.when<void>(
      success: (FeedPage page) {
        final FeedViewState latest = state.requireValue;
        final Map<String, FeedPost> merged = <String, FeedPost>{
          for (final FeedPost item in latest.items) item.id: item,
          for (final FeedPost item in page.items) item.id: item,
        };
        state = AsyncValue<FeedViewState>.data(
          latest.copyWith(
            items: merged.values.toList(growable: false),
            hasMore: page.hasMore,
            cursor: page.nextCursor,
            fromCache: page.fromCache,
            isLoadingMore: false,
          ),
        );
      },
      failure: (Failure failure) {
        final FeedViewState latest = state.requireValue;
        state = AsyncValue<FeedViewState>.data(
          latest.copyWith(isLoadingMore: false, failure: failure),
        );
      },
    );
  }

  Future<void> toggleReaction(String postId, PostReactionType type) async {
    final FeedViewState? current = state.value;
    if (current == null) {
      return;
    }
    final int index = current.items.indexWhere(
      (FeedPost post) => post.id == postId,
    );
    if (index < 0) {
      return;
    }
    final FeedPost original = current.items[index];
    final FeedPost optimistic = _optimistic(original, type);
    _replacePost(optimistic);

    final Result<ReactionMutationResult> result = await ref
        .read(postInteractionRepositoryProvider)
        .togglePostReaction(postId: postId, type: type);
    result.when<void>(
      success: (ReactionMutationResult mutation) {
        final FeedViewState? latestState = state.value;
        if (latestState == null) {
          return;
        }
        final FeedPost? latest = latestState.items
            .where((FeedPost item) => item.id == postId)
            .firstOrNull;
        if (latest == null) {
          return;
        }
        _replacePost(_applyServerMutation(latest, type, mutation));
      },
      failure: (Failure failure) {
        _replacePost(original);
        final FeedViewState latest = state.requireValue;
        state = AsyncValue<FeedViewState>.data(
          latest.copyWith(failure: failure),
        );
      },
    );
  }

  Future<void> recordView(String postId) async {
    await ref.read(postInteractionRepositoryProvider).recordPostView(postId);
  }

  void clearFailure() {
    final FeedViewState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncValue<FeedViewState>.data(
      current.copyWith(clearFailure: true),
    );
  }

  void _replacePost(FeedPost replacement) {
    final FeedViewState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncValue<FeedViewState>.data(
      current.copyWith(
        items: current.items
            .map(
              (FeedPost item) => item.id == replacement.id ? replacement : item,
            )
            .toList(growable: false),
      ),
    );
  }

  static FeedPost _optimistic(FeedPost post, PostReactionType type) {
    final PostViewerState viewer = post.viewerState;
    return switch (type) {
      PostReactionType.like => post.copyWith(
        likeCount: (post.likeCount + (viewer.isLiked ? -1 : 1))
            .clamp(0, 1 << 31)
            .toInt(),
        viewerState: viewer.copyWith(isLiked: !viewer.isLiked),
      ),
      PostReactionType.save => post.copyWith(
        saveCount: (post.saveCount + (viewer.isSaved ? -1 : 1))
            .clamp(0, 1 << 31)
            .toInt(),
        viewerState: viewer.copyWith(isSaved: !viewer.isSaved),
      ),
      PostReactionType.repost => post.copyWith(
        repostCount: (post.repostCount + (viewer.isReposted ? -1 : 1))
            .clamp(0, 1 << 31)
            .toInt(),
        viewerState: viewer.copyWith(isReposted: !viewer.isReposted),
      ),
    };
  }

  static FeedPost _applyServerMutation(
    FeedPost post,
    PostReactionType type,
    ReactionMutationResult mutation,
  ) {
    return switch (type) {
      PostReactionType.like => post.copyWith(
        likeCount: mutation.count,
        viewerState: post.viewerState.copyWith(isLiked: mutation.active),
      ),
      PostReactionType.save => post.copyWith(
        saveCount: mutation.count,
        viewerState: post.viewerState.copyWith(isSaved: mutation.active),
      ),
      PostReactionType.repost => post.copyWith(
        repostCount: mutation.count,
        viewerState: post.viewerState.copyWith(isReposted: mutation.active),
      ),
    };
  }

  Future<String> _requireUid() async {
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null) {
      throw StateError('A signed-in account is required.');
    }
    return user.uid;
  }
}

final FutureProvider<List<StoryGroup>> storyRailProvider =
    FutureProvider<List<StoryGroup>>((Ref ref) async {
      final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
      if (user == null) {
        return const <StoryGroup>[];
      }
      final Result<List<StoryGroup>> result = await ref
          .watch(storyRepositoryProvider)
          .loadStoryRail(viewerId: user.uid);
      return result.when<List<StoryGroup>>(
        success: (List<StoryGroup> value) => value,
        failure: (Failure failure) => throw StateError(failure.message),
      );
    });

final postByIdProvider = FutureProvider.family<FeedPost?, String>((
  Ref ref,
  String postId,
) async {
  final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
  if (user == null) {
    return null;
  }
  final Result<FeedPost?> result = await ref
      .watch(feedRepositoryProvider)
      .getPost(postId: postId, viewerId: user.uid);
  return result.when<FeedPost?>(
    success: (FeedPost? value) => value,
    failure: (Failure failure) => throw StateError(failure.message),
  );
});

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
