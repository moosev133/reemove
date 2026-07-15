import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';

class ContentReactionDto {
  const ContentReactionDto({
    required this.uid,
    required this.postId,
    required this.liked,
    required this.saved,
    required this.reposted,
  });

  factory ContentReactionDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap data = snapshot.data() ?? const <String, dynamic>{};
    return ContentReactionDto(
      uid: FirestoreParser.string(data, 'uid', fallback: ''),
      postId: FirestoreParser.string(data, 'postId', fallback: ''),
      liked: FirestoreParser.boolean(data, 'liked', fallback: false),
      saved: FirestoreParser.boolean(data, 'saved', fallback: false),
      reposted: FirestoreParser.boolean(data, 'reposted', fallback: false),
    );
  }

  final String uid;
  final String postId;
  final bool liked;
  final bool saved;
  final bool reposted;
}
