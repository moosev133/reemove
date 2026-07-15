import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/media_asset_dto.dart';
import '../../../../core/database/firestore_parser.dart';
import 'feed_post_dto.dart';

class StoryDto {
  const StoryDto({
    required this.id,
    required this.author,
    required this.media,
    required this.visibility,
    required this.moderationState,
    required this.createdAt,
    required this.expiresAt,
    required this.viewCount,
    this.caption,
    this.sportId,
  });

  factory StoryDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Story ${snapshot.id} is empty.');
    }
    return StoryDto(
      id: snapshot.id,
      author: PostAuthorSnapshotDto.fromMap(
        FirestoreParser.map(data, 'authorSnapshot'),
      ),
      media: MediaAssetDto.fromMap(FirestoreParser.map(data, 'media')),
      caption: FirestoreParser.nullableString(data, 'caption'),
      sportId: FirestoreParser.nullableString(data, 'sportId'),
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
      createdAt: FirestoreParser.dateTime(data, 'createdAt'),
      expiresAt: FirestoreParser.dateTime(data, 'expiresAt'),
      viewCount: FirestoreParser.integer(data, 'viewCount', fallback: 0),
    );
  }

  final String id;
  final PostAuthorSnapshotDto author;
  final MediaAssetDto media;
  final String? caption;
  final String? sportId;
  final String visibility;
  final String moderationState;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
}
