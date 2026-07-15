import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/media_asset.dart';
import 'feed_post.dart';

class Story {
  const Story({
    required this.id,
    required this.author,
    required this.media,
    required this.visibility,
    required this.moderationState,
    required this.createdAt,
    required this.expiresAt,
    required this.viewCount,
    required this.isViewed,
    this.caption,
    this.sportId,
  });

  final String id;
  final PostAuthorSnapshot author;
  final MediaAsset media;
  final String? caption;
  final String? sportId;
  final Visibility visibility;
  final ModerationState moderationState;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final bool isViewed;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}

class StoryGroup {
  const StoryGroup({required this.author, required this.stories});

  final PostAuthorSnapshot author;
  final List<Story> stories;

  bool get hasUnseen => stories.any((Story story) => !story.isViewed);
}
