import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';
import 'feed_post_dto.dart';

class PostCommentDto {
  const PostCommentDto({
    required this.id,
    required this.postId,
    required this.author,
    required this.text,
    required this.likeCount,
    required this.replyCount,
    required this.createdAt,
    required this.isDeleted,
    this.parentCommentId,
    this.editedAt,
  });

  factory PostCommentDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Comment ${snapshot.id} is empty.');
    }
    return PostCommentDto(
      id: snapshot.id,
      postId: FirestoreParser.string(data, 'postId'),
      author: PostAuthorSnapshotDto.fromMap(
        FirestoreParser.map(data, 'authorSnapshot'),
      ),
      text: FirestoreParser.string(data, 'text', fallback: ''),
      parentCommentId: FirestoreParser.nullableString(data, 'parentCommentId'),
      likeCount: FirestoreParser.integer(data, 'likeCount', fallback: 0),
      replyCount: FirestoreParser.integer(data, 'replyCount', fallback: 0),
      createdAt: FirestoreParser.dateTime(data, 'createdAt'),
      editedAt: FirestoreParser.nullableDateTime(data, 'editedAt'),
      isDeleted: FirestoreParser.boolean(data, 'isDeleted', fallback: false),
    );
  }

  final String id;
  final String postId;
  final PostAuthorSnapshotDto author;
  final String text;
  final String? parentCommentId;
  final int likeCount;
  final int replyCount;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;
}
