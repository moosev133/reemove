import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/media_asset.dart';

enum FeedMode { forYou, following }

enum PostKind { post, reel }

class PostAuthorSnapshot {
  const PostAuthorSnapshot({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
    required this.verificationType,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final String verificationType;
}

class PostViewerState {
  const PostViewerState({
    this.isLiked = false,
    this.isSaved = false,
    this.isReposted = false,
  });

  final bool isLiked;
  final bool isSaved;
  final bool isReposted;

  PostViewerState copyWith({bool? isLiked, bool? isSaved, bool? isReposted}) {
    return PostViewerState(
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isReposted: isReposted ?? this.isReposted,
    );
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.author,
    required this.kind,
    required this.caption,
    required this.media,
    required this.hashtags,
    required this.mentions,
    required this.visibility,
    required this.moderationState,
    required this.status,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.repostCount,
    required this.viewCount,
    required this.rankingScore,
    required this.publishedAt,
    required this.viewerState,
    this.sportId,
    this.locationLabel,
    this.editedAt,
    this.originalPostId,
    this.originalAuthorId,
  });

  final String id;
  final PostAuthorSnapshot author;
  final PostKind kind;
  final String caption;
  final List<MediaAsset> media;
  final List<String> hashtags;
  final List<String> mentions;
  final String? sportId;
  final String? locationLabel;
  final Visibility visibility;
  final ModerationState moderationState;
  final String status;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int repostCount;
  final int viewCount;
  final double rankingScore;
  final DateTime publishedAt;
  final DateTime? editedAt;
  final String? originalPostId;
  final String? originalAuthorId;
  final PostViewerState viewerState;

  bool get isVideo =>
      media.any((MediaAsset item) => item.kind == MediaKind.video);
  bool get isPublished => status == 'published';

  FeedPost copyWith({
    String? caption,
    int? likeCount,
    int? commentCount,
    int? saveCount,
    int? repostCount,
    int? viewCount,
    PostViewerState? viewerState,
  }) {
    return FeedPost(
      id: id,
      author: author,
      kind: kind,
      caption: caption ?? this.caption,
      media: media,
      hashtags: hashtags,
      mentions: mentions,
      sportId: sportId,
      locationLabel: locationLabel,
      visibility: visibility,
      moderationState: moderationState,
      status: status,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      repostCount: repostCount ?? this.repostCount,
      viewCount: viewCount ?? this.viewCount,
      rankingScore: rankingScore,
      publishedAt: publishedAt,
      editedAt: editedAt,
      originalPostId: originalPostId,
      originalAuthorId: originalAuthorId,
      viewerState: viewerState ?? this.viewerState,
    );
  }
}
