import '../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/feed_post.dart';
import '../dto/content_reaction_dto.dart';
import '../dto/feed_post_dto.dart';

extension PostAuthorSnapshotDtoMapper on PostAuthorSnapshotDto {
  PostAuthorSnapshot toDomain() => PostAuthorSnapshot(
    id: id,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    isVerified: isVerified,
    verificationType: verificationType,
  );
}

extension FeedPostDtoMapper on FeedPostDto {
  FeedPost toDomain({ContentReactionDto? reaction}) => FeedPost(
    id: id,
    author: author.toDomain(),
    kind: PostKind.values.byName(kind),
    caption: caption,
    media: media.map((item) => item.toDomain()).toList(growable: false),
    hashtags: hashtags,
    mentions: mentions,
    sportId: sportId,
    locationLabel: locationLabel,
    visibility: VisibilityStorageValue.fromStorage(visibility),
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    status: status,
    likeCount: likeCount,
    commentCount: commentCount,
    saveCount: saveCount,
    repostCount: repostCount,
    viewCount: viewCount,
    rankingScore: rankingScore,
    publishedAt: publishedAt,
    editedAt: editedAt,
    originalPostId: originalPostId,
    originalAuthorId: originalAuthorId,
    viewerState: PostViewerState(
      isLiked: reaction?.liked ?? false,
      isSaved: reaction?.saved ?? false,
      isReposted: reaction?.reposted ?? false,
    ),
  );
}
