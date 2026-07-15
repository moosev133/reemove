import '../../../../core/result/result.dart';
import '../entities/feed_page.dart';
import '../entities/feed_post.dart';

abstract interface class FeedRepository {
  Future<Result<FeedPage>> loadFeed({
    required String viewerId,
    required FeedMode mode,
    FeedCursor? cursor,
    int limit = 10,
    bool cacheOnly = false,
  });

  Future<Result<FeedPage>> loadReels({
    required String viewerId,
    FeedCursor? cursor,
    int limit = 8,
  });

  Future<Result<FeedPost?>> getPost({
    required String postId,
    required String viewerId,
  });
}
