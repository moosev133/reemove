import 'feed_post.dart';

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.text,
    required this.likeCount,
    required this.replyCount,
    required this.createdAt,
    required this.isLiked,
    required this.isDeleted,
    this.parentCommentId,
    this.editedAt,
  });

  final String id;
  final String postId;
  final PostAuthorSnapshot author;
  final String text;
  final String? parentCommentId;
  final int likeCount;
  final int replyCount;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isLiked;
  final bool isDeleted;

  PostComment copyWith({
    String? text,
    int? likeCount,
    int? replyCount,
    bool? isLiked,
    bool? isDeleted,
  }) {
    return PostComment(
      id: id,
      postId: postId,
      author: author,
      text: text ?? this.text,
      parentCommentId: parentCommentId,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      createdAt: createdAt,
      editedAt: editedAt,
      isLiked: isLiked ?? this.isLiked,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class CommentPage {
  const CommentPage({
    required this.items,
    required this.hasMore,
    this.cursorCreatedAt,
    this.cursorDocumentId,
  });

  final List<PostComment> items;
  final bool hasMore;
  final DateTime? cursorCreatedAt;
  final String? cursorDocumentId;
}
