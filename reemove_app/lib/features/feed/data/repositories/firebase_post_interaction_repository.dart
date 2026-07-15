import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/functions_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/content_report.dart';
import '../../domain/entities/post_comment.dart';
import '../../domain/repositories/post_interaction_repository.dart';
import '../dto/post_comment_dto.dart';
import '../mappers/post_comment_mapper.dart';

class FirebasePostInteractionRepository implements PostInteractionRepository {
  const FirebasePostInteractionRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _functions = functions,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  Future<Result<ReactionMutationResult>> togglePostReaction({
    required String postId,
    required PostReactionType type,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('togglePostReaction')
          .call<dynamic>(<String, Object?>{
            'postId': postId,
            'type': type.name,
          });
      final Map<String, dynamic> data = _map(response.data);
      return Success<ReactionMutationResult>(
        ReactionMutationResult(
          active: data['active'] == true,
          count: _integer(data['count']),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<ReactionMutationResult>(
        FunctionsFailureMapper.fromException(error),
      );
    } catch (error) {
      return FailureResult<ReactionMutationResult>(_unexpected(error));
    }
  }

  @override
  Future<Result<CommentPage>> loadComments({
    required String postId,
    DateTime? cursorCreatedAt,
    String? cursorDocumentId,
    int limit = 20,
  }) async {
    try {
      Query<PostCommentDto> query = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .withConverter<PostCommentDto>(
            fromFirestore: PostCommentDto.fromFirestore,
            toFirestore: (_, _) => throw UnsupportedError('Read only.'),
          )
          .where('moderationState', isEqualTo: 'active')
          .where('parentCommentId', isNull: true)
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(limit + 1);
      if (cursorCreatedAt != null && cursorDocumentId != null) {
        query = query.startAfter(<Object>[
          Timestamp.fromDate(cursorCreatedAt.toUtc()),
          cursorDocumentId,
        ]);
      }
      final QuerySnapshot<PostCommentDto> snapshot = await query.get();
      final bool hasMore = snapshot.docs.length > limit;
      final List<QueryDocumentSnapshot<PostCommentDto>> docs = snapshot.docs
          .take(limit)
          .toList(growable: false);
      final String uid = _requireUid();
      final List<DocumentSnapshot<Map<String, dynamic>>> reactions =
          await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
            docs.map(
              (QueryDocumentSnapshot<PostCommentDto> doc) => _firestore
                  .collection('comment_reactions')
                  .doc('$uid--${doc.id}')
                  .get(),
            ),
          );
      final Set<String> likedCommentIds = reactions
          .where(
            (DocumentSnapshot<Map<String, dynamic>> item) =>
                item.data()?['liked'] == true,
          )
          .map(
            (DocumentSnapshot<Map<String, dynamic>> item) =>
                item.data()?['commentId'],
          )
          .whereType<String>()
          .toSet();
      final List<PostComment> comments = docs
          .map(
            (QueryDocumentSnapshot<PostCommentDto> doc) =>
                doc.data().toDomain(isLiked: likedCommentIds.contains(doc.id)),
          )
          .toList(growable: false);
      final PostCommentDto? last = docs.isEmpty ? null : docs.last.data();
      return Success<CommentPage>(
        CommentPage(
          items: comments,
          hasMore: hasMore,
          cursorCreatedAt: last?.createdAt,
          cursorDocumentId: docs.isEmpty ? null : docs.last.id,
        ),
      );
    } on FirebaseException catch (error) {
      return FailureResult<CommentPage>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<CommentPage>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      return FailureResult<CommentPage>(_unexpected(error));
    }
  }

  @override
  Future<Result<PostComment>> createComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('createPostComment')
          .call<dynamic>(<String, Object?>{
            'postId': postId,
            'text': text,
            'parentCommentId': ?parentCommentId,
          });
      final String commentId = _map(response.data)['commentId'] as String;
      final DocumentSnapshot<PostCommentDto> snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .withConverter<PostCommentDto>(
            fromFirestore: PostCommentDto.fromFirestore,
            toFirestore: (_, _) => throw UnsupportedError('Read only.'),
          )
          .doc(commentId)
          .get();
      final PostCommentDto? comment = snapshot.data();
      if (comment == null) {
        throw StateError('The new comment could not be loaded.');
      }
      return Success<PostComment>(comment.toDomain(isLiked: false));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<PostComment>(
        FunctionsFailureMapper.fromException(error),
      );
    } on FirebaseException catch (error) {
      return FailureResult<PostComment>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } catch (error) {
      return FailureResult<PostComment>(_unexpected(error));
    }
  }

  @override
  Future<Result<ReactionMutationResult>> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('toggleCommentLike')
          .call<dynamic>(<String, Object?>{
            'postId': postId,
            'commentId': commentId,
          });
      final Map<String, dynamic> data = _map(response.data);
      return Success<ReactionMutationResult>(
        ReactionMutationResult(
          active: data['active'] == true,
          count: _integer(data['count']),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<ReactionMutationResult>(
        FunctionsFailureMapper.fromException(error),
      );
    } catch (error) {
      return FailureResult<ReactionMutationResult>(_unexpected(error));
    }
  }

  @override
  Future<Result<void>> deleteComment({
    required String postId,
    required String commentId,
  }) => _callVoid('deletePostComment', <String, Object?>{
    'postId': postId,
    'commentId': commentId,
  });

  @override
  Future<Result<void>> recordPostView(String postId) =>
      _callVoid('recordPostView', <String, Object?>{'postId': postId});

  @override
  Future<Result<void>> report(ContentReportRequest request) =>
      _callVoid('reportContent', <String, Object?>{
        'targetType': request.targetType,
        'targetId': request.targetId,
        'reason': request.reason.name,
        if (request.details != null) 'details': request.details,
      });

  @override
  Future<Result<void>> blockUser(String targetUserId) =>
      _callVoid('blockUser', <String, Object?>{'targetUserId': targetUserId});

  Future<Result<void>> _callVoid(String name, Map<String, Object?> data) async {
    try {
      await _functions.httpsCallable(name).call<Object?>(data);
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(FunctionsFailureMapper.fromException(error));
    } catch (error) {
      return FailureResult<void>(_unexpected(error));
    }
  }

  String _requireUid() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('A signed-in account is required.');
    }
    return uid;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const FormatException('The server returned an invalid response.');
  }

  static int _integer(Object? value) => value is num ? value.toInt() : 0;

  static Failure _unexpected(Object error) => Failure(
    message: 'ReeMove could not update this content. Try again.',
    code: 'feed/interaction-failed',
    debugMessage: error.toString(),
    cause: error,
  );
}
