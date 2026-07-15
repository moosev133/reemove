import '../../../../core/result/result.dart';
import '../entities/content_report.dart';
import '../entities/post_comment.dart';

enum PostReactionType { like, save, repost }

class ReactionMutationResult {
  const ReactionMutationResult({required this.active, required this.count});

  final bool active;
  final int count;
}

abstract interface class PostInteractionRepository {
  Future<Result<ReactionMutationResult>> togglePostReaction({
    required String postId,
    required PostReactionType type,
  });

  Future<Result<CommentPage>> loadComments({
    required String postId,
    DateTime? cursorCreatedAt,
    String? cursorDocumentId,
    int limit = 20,
  });

  Future<Result<PostComment>> createComment({
    required String postId,
    required String text,
    String? parentCommentId,
  });

  Future<Result<ReactionMutationResult>> toggleCommentLike({
    required String postId,
    required String commentId,
  });

  Future<Result<void>> deleteComment({
    required String postId,
    required String commentId,
  });

  Future<Result<void>> recordPostView(String postId);
  Future<Result<void>> report(ContentReportRequest request);
  Future<Result<void>> blockUser(String targetUserId);
}
