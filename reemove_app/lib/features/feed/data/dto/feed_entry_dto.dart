import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';

class FeedEntryDto {
  const FeedEntryDto({
    required this.id,
    required this.recipientId,
    required this.postId,
    required this.authorId,
    required this.rankingScore,
    required this.publishedAt,
  });

  factory FeedEntryDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Feed entry ${snapshot.id} is empty.');
    }
    return FeedEntryDto(
      id: snapshot.id,
      recipientId: FirestoreParser.string(data, 'recipientId'),
      postId: FirestoreParser.string(data, 'postId'),
      authorId: FirestoreParser.string(data, 'authorId', fallback: ''),
      rankingScore: FirestoreParser.number(data, 'rankingScore', fallback: 0),
      publishedAt: FirestoreParser.dateTime(data, 'publishedAt'),
    );
  }

  final String id;
  final String recipientId;
  final String postId;
  final String authorId;
  final double rankingScore;
  final DateTime publishedAt;
}
