import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/media_asset_dto.dart';
import '../../../../core/database/firestore_parser.dart';

class PostAuthorSnapshotDto {
  const PostAuthorSnapshotDto({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
    required this.verificationType,
    this.avatarUrl,
  });

  factory PostAuthorSnapshotDto.fromMap(FirestoreMap data) {
    return PostAuthorSnapshotDto(
      id: FirestoreParser.string(data, 'id'),
      username: FirestoreParser.string(data, 'username'),
      displayName: FirestoreParser.string(data, 'displayName'),
      avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
      verificationType: FirestoreParser.string(
        data,
        'verificationType',
        fallback: 'none',
      ),
    );
  }

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final String verificationType;

  FirestoreMap toMap() => <String, Object?>{
    'id': id,
    'username': username,
    'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'isVerified': isVerified,
    'verificationType': verificationType,
  };
}

class FeedPostDto {
  const FeedPostDto({
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
    required this.allowComments,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.repostCount,
    required this.viewCount,
    required this.rankingScore,
    required this.publishedAt,
    this.sportId,
    this.locationLabel,
    this.editedAt,
    this.originalPostId,
    this.originalAuthorId,
  });

  factory FeedPostDto.fromMap(FirestoreMap data, {required String documentId}) {
    return FeedPostDto(
      id: documentId,
      author: PostAuthorSnapshotDto.fromMap(
        FirestoreParser.map(data, 'authorSnapshot'),
      ),
      kind: FirestoreParser.string(data, 'kind', fallback: 'post'),
      caption: FirestoreParser.string(data, 'caption', fallback: ''),
      media: FirestoreParser.mapList(
        data,
        'media',
      ).map(MediaAssetDto.fromMap).toList(growable: false),
      hashtags: FirestoreParser.stringList(data, 'hashtags'),
      mentions: FirestoreParser.stringList(data, 'mentions'),
      sportId: FirestoreParser.nullableString(data, 'sportId'),
      locationLabel: FirestoreParser.nullableString(data, 'locationLabel'),
      visibility: FirestoreParser.string(
        data,
        'visibility',
        fallback: 'public',
      ),
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      status: FirestoreParser.string(data, 'status', fallback: 'published'),
      allowComments: FirestoreParser.boolean(
        data,
        'allowComments',
        fallback: true,
      ),
      likeCount: FirestoreParser.integer(data, 'likeCount', fallback: 0),
      commentCount: FirestoreParser.integer(data, 'commentCount', fallback: 0),
      saveCount: FirestoreParser.integer(data, 'saveCount', fallback: 0),
      repostCount: FirestoreParser.integer(data, 'repostCount', fallback: 0),
      viewCount: FirestoreParser.integer(data, 'viewCount', fallback: 0),
      rankingScore: FirestoreParser.number(data, 'rankingScore', fallback: 0),
      publishedAt: FirestoreParser.dateTime(data, 'publishedAt'),
      editedAt: FirestoreParser.nullableDateTime(data, 'editedAt'),
      originalPostId: FirestoreParser.nullableString(data, 'originalPostId'),
      originalAuthorId: FirestoreParser.nullableString(
        data,
        'originalAuthorId',
      ),
    );
  }

  factory FeedPostDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Post ${snapshot.id} has no data.');
    }
    return FeedPostDto.fromMap(data, documentId: snapshot.id);
  }

  final String id;
  final PostAuthorSnapshotDto author;
  final String kind;
  final String caption;
  final List<MediaAssetDto> media;
  final List<String> hashtags;
  final List<String> mentions;
  final String? sportId;
  final String? locationLabel;
  final String visibility;
  final String moderationState;
  final String status;
  final bool allowComments;
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

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'authorId': author.id,
    'authorSnapshot': author.toMap(),
    'kind': kind,
    'caption': caption,
    'media': media.map((MediaAssetDto item) => item.toMap()).toList(),
    'hashtags': hashtags,
    'mentions': mentions,
    if (sportId != null) 'sportId': sportId,
    if (locationLabel != null) 'locationLabel': locationLabel,
    'visibility': visibility,
    'moderationState': moderationState,
    'status': status,
    'allowComments': allowComments,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'saveCount': saveCount,
    'repostCount': repostCount,
    'viewCount': viewCount,
    'rankingScore': rankingScore,
    'publishedAt': Timestamp.fromDate(publishedAt.toUtc()),
    if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!.toUtc()),
    if (originalPostId != null) 'originalPostId': originalPostId,
    if (originalAuthorId != null) 'originalAuthorId': originalAuthorId,
  };
}
