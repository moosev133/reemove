import '../../domain/entities/post_comment.dart';
import '../dto/post_comment_dto.dart';
import 'feed_post_mapper.dart';

extension PostCommentDtoMapper on PostCommentDto {
  PostComment toDomain({required bool isLiked}) => PostComment(
    id: id,
    postId: postId,
    author: author.toDomain(),
    text: text,
    parentCommentId: parentCommentId,
    likeCount: likeCount,
    replyCount: replyCount,
    createdAt: createdAt,
    editedAt: editedAt,
    isLiked: isLiked,
    isDeleted: isDeleted,
  );
}
