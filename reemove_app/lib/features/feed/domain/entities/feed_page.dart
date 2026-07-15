import 'feed_post.dart';

class FeedCursor {
  const FeedCursor({
    required this.documentId,
    required this.publishedAt,
    this.rankingScore,
  });

  final String documentId;
  final DateTime publishedAt;
  final double? rankingScore;
}

class FeedPage {
  const FeedPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.fromCache = false,
  });

  final List<FeedPost> items;
  final bool hasMore;
  final FeedCursor? nextCursor;
  final bool fromCache;
}
