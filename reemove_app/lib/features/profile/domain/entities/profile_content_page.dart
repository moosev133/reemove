import '../../../feed/domain/entities/feed_post.dart';

enum ProfileContentFilter { posts, reels, saved, reposted }

class ProfileContentCursor {
  const ProfileContentCursor({required this.documentId, required this.sortAt});

  final String documentId;
  final DateTime sortAt;
}

class ProfileContentPage {
  const ProfileContentPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<FeedPost> items;
  final bool hasMore;
  final ProfileContentCursor? nextCursor;
}
