import '../../../core/errors/failure.dart';
import '../domain/entities/feed_page.dart';
import '../domain/entities/feed_post.dart';

class FeedViewState {
  const FeedViewState({
    required this.mode,
    required this.items,
    required this.hasMore,
    required this.fromCache,
    this.cursor,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.failure,
  });

  factory FeedViewState.fromPage(FeedMode mode, FeedPage page) => FeedViewState(
    mode: mode,
    items: page.items,
    hasMore: page.hasMore,
    cursor: page.nextCursor,
    fromCache: page.fromCache,
  );

  final FeedMode mode;
  final List<FeedPost> items;
  final bool hasMore;
  final FeedCursor? cursor;
  final bool fromCache;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Failure? failure;

  FeedViewState copyWith({
    FeedMode? mode,
    List<FeedPost>? items,
    bool? hasMore,
    FeedCursor? cursor,
    bool clearCursor = false,
    bool? fromCache,
    bool? isRefreshing,
    bool? isLoadingMore,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return FeedViewState(
      mode: mode ?? this.mode,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : cursor ?? this.cursor,
      fromCache: fromCache ?? this.fromCache,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
