import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/feed_page.dart';
import '../../domain/entities/feed_post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../dto/content_reaction_dto.dart';
import '../dto/feed_entry_dto.dart';
import '../dto/feed_post_dto.dart';
import '../mappers/feed_post_mapper.dart';

class FirebaseFeedRepository implements FeedRepository {
  const FirebaseFeedRepository({
    required FirebaseFirestore firestore,
    required CollectionReference<FeedPostDto> posts,
    required CollectionReference<FeedEntryDto> feedEntries,
    required CollectionReference<ContentReactionDto> reactions,
  }) : _firestore = firestore,
       _posts = posts,
       _feedEntries = feedEntries,
       _reactions = reactions;

  final FirebaseFirestore _firestore;
  final CollectionReference<FeedPostDto> _posts;
  final CollectionReference<FeedEntryDto> _feedEntries;
  final CollectionReference<ContentReactionDto> _reactions;

  @override
  Future<Result<FeedPage>> loadFeed({
    required String viewerId,
    required FeedMode mode,
    FeedCursor? cursor,
    int limit = 10,
    bool cacheOnly = false,
  }) async {
    try {
      final Set<String> blockedUserIds = await _loadHiddenUserIds(
        viewerId,
        cacheOnly: cacheOnly,
      );
      return mode == FeedMode.forYou
          ? await _loadForYou(
              viewerId: viewerId,
              blockedUserIds: blockedUserIds,
              cursor: cursor,
              limit: limit,
              cacheOnly: cacheOnly,
            )
          : await _loadFollowing(
              viewerId: viewerId,
              blockedUserIds: blockedUserIds,
              cursor: cursor,
              limit: limit,
              cacheOnly: cacheOnly,
            );
    } on FirebaseException catch (error) {
      return FailureResult<FeedPage>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<FeedPage>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      return FailureResult<FeedPage>(FirestoreFailureMapper.unexpected(error));
    }
  }

  Future<Result<FeedPage>> _loadForYou({
    required String viewerId,
    required Set<String> blockedUserIds,
    required FeedCursor? cursor,
    required int limit,
    required bool cacheOnly,
    int emptyPageAttempts = 0,
  }) async {
    final int fetchLimit = _overscanLimit(limit, maximum: 25);
    Query<FeedPostDto> query = _posts
        .where('status', isEqualTo: 'published')
        .where('moderationState', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public')
        .where('authorAccountVisibility', isEqualTo: 'public')
        .orderBy('rankingScore', descending: true)
        .orderBy('publishedAt', descending: true)
        .orderBy(FieldPath.documentId)
        .limit(fetchLimit);
    if (cursor != null) {
      query = query.startAfter(<Object>[
        cursor.rankingScore ?? 0,
        Timestamp.fromDate(cursor.publishedAt.toUtc()),
        cursor.documentId,
      ]);
    }
    final QuerySnapshot<FeedPostDto> snapshot = await query.get(
      GetOptions(source: cacheOnly ? Source.cache : Source.serverAndCache),
    );
    final List<QueryDocumentSnapshot<FeedPostDto>> accessible = snapshot.docs
        .where(
          (QueryDocumentSnapshot<FeedPostDto> item) =>
              !blockedUserIds.contains(item.data().author.id),
        )
        .toList(growable: false);
    final List<QueryDocumentSnapshot<FeedPostDto>> documents = accessible
        .take(limit)
        .toList(growable: false);
    final bool hasMore =
        accessible.length > limit || snapshot.docs.length == fetchLimit;

    if (documents.isEmpty &&
        hasMore &&
        snapshot.docs.isNotEmpty &&
        emptyPageAttempts < 3) {
      final QueryDocumentSnapshot<FeedPostDto> rawLast = snapshot.docs.last;
      return _loadForYou(
        viewerId: viewerId,
        blockedUserIds: blockedUserIds,
        cursor: _postCursor(rawLast),
        limit: limit,
        cacheOnly: cacheOnly,
        emptyPageAttempts: emptyPageAttempts + 1,
      );
    }

    return _pageFromPosts(
      documents: documents,
      viewerId: viewerId,
      hasMore: hasMore,
      fromCache: snapshot.metadata.isFromCache,
      fallbackCursorDocument: documents.isEmpty && snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : null,
    );
  }

  Future<Result<FeedPage>> _loadFollowing({
    required String viewerId,
    required Set<String> blockedUserIds,
    required FeedCursor? cursor,
    required int limit,
    required bool cacheOnly,
    int emptyPageAttempts = 0,
  }) async {
    final int fetchLimit = _overscanLimit(limit, maximum: 25);
    Query<FeedEntryDto> query = _feedEntries
        .where('recipientId', isEqualTo: viewerId)
        .orderBy('rankingScore', descending: true)
        .orderBy('publishedAt', descending: true)
        .orderBy(FieldPath.documentId)
        .limit(fetchLimit);
    if (cursor != null) {
      query = query.startAfter(<Object>[
        cursor.rankingScore ?? 0,
        Timestamp.fromDate(cursor.publishedAt.toUtc()),
        cursor.documentId,
      ]);
    }
    final QuerySnapshot<FeedEntryDto> snapshot = await query.get(
      GetOptions(source: cacheOnly ? Source.cache : Source.serverAndCache),
    );
    final List<QueryDocumentSnapshot<FeedEntryDto>> accessibleEntries = snapshot
        .docs
        .where(
          (QueryDocumentSnapshot<FeedEntryDto> item) =>
              item.data().authorId.isNotEmpty &&
              !blockedUserIds.contains(item.data().authorId),
        )
        .take(limit)
        .toList(growable: false);

    if (accessibleEntries.isEmpty &&
        snapshot.docs.length == fetchLimit &&
        snapshot.docs.isNotEmpty &&
        emptyPageAttempts < 3) {
      final QueryDocumentSnapshot<FeedEntryDto> rawLast = snapshot.docs.last;
      return _loadFollowing(
        viewerId: viewerId,
        blockedUserIds: blockedUserIds,
        cursor: _entryCursor(rawLast),
        limit: limit,
        cacheOnly: cacheOnly,
        emptyPageAttempts: emptyPageAttempts + 1,
      );
    }

    final List<FeedPostDto> posts = <FeedPostDto>[];
    final Map<String, FeedEntryDto> byPostId = <String, FeedEntryDto>{};
    for (final QueryDocumentSnapshot<FeedEntryDto> entry in accessibleEntries) {
      try {
        final DocumentSnapshot<FeedPostDto> postSnapshot = await _posts
            .doc(entry.data().postId)
            .get(
              GetOptions(
                source: cacheOnly ? Source.cache : Source.serverAndCache,
              ),
            );
        final FeedPostDto? post = postSnapshot.data();
        if (post == null || blockedUserIds.contains(post.author.id)) {
          continue;
        }
        posts.add(post);
        byPostId[post.id] = entry.data();
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied' && error.code != 'not-found') {
          rethrow;
        }
      }
    }
    posts.sort((FeedPostDto a, FeedPostDto b) {
      final double left = byPostId[a.id]?.rankingScore ?? 0;
      final double right = byPostId[b.id]?.rankingScore ?? 0;
      return right.compareTo(left);
    });
    final List<FeedPost> mapped = await _withViewerState(posts, viewerId);
    final QueryDocumentSnapshot<FeedEntryDto>? lastEntry =
        accessibleEntries.isNotEmpty
        ? accessibleEntries.last
        : (snapshot.docs.isEmpty ? null : snapshot.docs.last);
    final bool hasMore = snapshot.docs.length == fetchLimit;
    return Success<FeedPage>(
      FeedPage(
        items: mapped,
        hasMore: hasMore,
        nextCursor: lastEntry == null ? null : _entryCursor(lastEntry),
        fromCache: snapshot.metadata.isFromCache,
      ),
    );
  }

  Future<Result<FeedPage>> _pageFromPosts({
    required List<QueryDocumentSnapshot<FeedPostDto>> documents,
    required String viewerId,
    required bool hasMore,
    required bool fromCache,
    QueryDocumentSnapshot<FeedPostDto>? fallbackCursorDocument,
  }) async {
    final List<FeedPostDto> dtos = documents
        .map((QueryDocumentSnapshot<FeedPostDto> item) => item.data())
        .toList(growable: false);
    final List<FeedPost> items = await _withViewerState(dtos, viewerId);
    final QueryDocumentSnapshot<FeedPostDto>? cursorDocument =
        documents.isNotEmpty ? documents.last : fallbackCursorDocument;
    return Success<FeedPage>(
      FeedPage(
        items: items,
        hasMore: hasMore,
        nextCursor: cursorDocument == null ? null : _postCursor(cursorDocument),
        fromCache: fromCache,
      ),
    );
  }

  Future<List<FeedPost>> _withViewerState(
    List<FeedPostDto> posts,
    String viewerId,
  ) async {
    if (posts.isEmpty) {
      return const <FeedPost>[];
    }
    final List<DocumentSnapshot<ContentReactionDto>> reactionSnapshots =
        await Future.wait<DocumentSnapshot<ContentReactionDto>>(
          posts.map(
            (FeedPostDto post) => _reactions.doc('$viewerId--${post.id}').get(),
          ),
        );
    final Map<String, ContentReactionDto> reactions =
        <String, ContentReactionDto>{};
    for (final DocumentSnapshot<ContentReactionDto> snapshot
        in reactionSnapshots) {
      final ContentReactionDto? reaction = snapshot.data();
      if (reaction != null) {
        reactions[reaction.postId] = reaction;
      }
    }
    return posts
        .map((FeedPostDto post) => post.toDomain(reaction: reactions[post.id]))
        .toList(growable: false);
  }

  @override
  Future<Result<FeedPage>> loadReels({
    required String viewerId,
    FeedCursor? cursor,
    int limit = 8,
  }) async {
    try {
      final Set<String> blockedUserIds = await _loadHiddenUserIds(viewerId);
      final int fetchLimit = _overscanLimit(limit, maximum: 25);
      Query<FeedPostDto> query = _posts
          .where('kind', isEqualTo: 'reel')
          .where('status', isEqualTo: 'published')
          .where('moderationState', isEqualTo: 'active')
          .where('visibility', isEqualTo: 'public')
          .orderBy('rankingScore', descending: true)
          .orderBy('publishedAt', descending: true)
          .orderBy(FieldPath.documentId)
          .limit(fetchLimit);
      if (cursor != null) {
        query = query.startAfter(<Object>[
          cursor.rankingScore ?? 0,
          Timestamp.fromDate(cursor.publishedAt.toUtc()),
          cursor.documentId,
        ]);
      }
      final QuerySnapshot<FeedPostDto> snapshot = await query.get();
      final List<QueryDocumentSnapshot<FeedPostDto>> accessible = snapshot.docs
          .where(
            (QueryDocumentSnapshot<FeedPostDto> item) =>
                !blockedUserIds.contains(item.data().author.id),
          )
          .toList(growable: false);
      final List<QueryDocumentSnapshot<FeedPostDto>> documents = accessible
          .take(limit)
          .toList(growable: false);
      final bool hasMore =
          accessible.length > limit || snapshot.docs.length == fetchLimit;
      return _pageFromPosts(
        documents: documents,
        viewerId: viewerId,
        hasMore: hasMore,
        fromCache: snapshot.metadata.isFromCache,
        fallbackCursorDocument: documents.isEmpty && snapshot.docs.isNotEmpty
            ? snapshot.docs.last
            : null,
      );
    } on FirebaseException catch (error) {
      return FailureResult<FeedPage>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<FeedPage>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      return FailureResult<FeedPage>(_unexpected(error));
    }
  }

  @override
  Future<Result<FeedPost?>> getPost({
    required String postId,
    required String viewerId,
  }) async {
    try {
      final DocumentSnapshot<FeedPostDto> snapshot = await _posts
          .doc(postId)
          .get();
      final FeedPostDto? post = snapshot.data();
      if (post == null) {
        return const Success<FeedPost?>(null);
      }
      final ContentReactionDto? reaction =
          (await _reactions.doc('$viewerId--$postId').get()).data();
      return Success<FeedPost?>(post.toDomain(reaction: reaction));
    } on FirebaseException catch (error) {
      return FailureResult<FeedPost?>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<FeedPost?>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      return FailureResult<FeedPost?>(_unexpected(error));
    }
  }

  Future<Set<String>> _loadHiddenUserIds(
    String viewerId, {
    bool cacheOnly = false,
  }) async {
    final Set<String> userIds = <String>{};
    final DocumentReference<Map<String, dynamic>> user = _firestore
        .collection('users')
        .doc(viewerId);
    for (final CollectionReference<Map<String, dynamic>> collection
        in <CollectionReference<Map<String, dynamic>>>[
          user.collection('blocks'),
          user.collection('blocked_by'),
        ]) {
      QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        Query<Map<String, dynamic>> query = collection
            .orderBy(FieldPath.documentId)
            .limit(100);
        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }
        final QuerySnapshot<Map<String, dynamic>> page = await query.get(
          GetOptions(source: cacheOnly ? Source.cache : Source.serverAndCache),
        );
        userIds.addAll(page.docs.map((item) => item.id));
        if (page.docs.length < 100) {
          break;
        }
        cursor = page.docs.last;
      }
    }
    return userIds;
  }

  static int _overscanLimit(int limit, {required int maximum}) {
    final int candidate = (limit * 2) + 1;
    return candidate > maximum ? maximum : candidate;
  }

  static FeedCursor _postCursor(QueryDocumentSnapshot<FeedPostDto> document) {
    final FeedPostDto value = document.data();
    return FeedCursor(
      documentId: document.id,
      publishedAt: value.publishedAt,
      rankingScore: value.rankingScore,
    );
  }

  static FeedCursor _entryCursor(QueryDocumentSnapshot<FeedEntryDto> document) {
    final FeedEntryDto value = document.data();
    return FeedCursor(
      documentId: document.id,
      publishedAt: value.publishedAt,
      rankingScore: value.rankingScore,
    );
  }

  static Failure _unexpected(Object error) =>
      FirestoreFailureMapper.unexpected(error);
}
