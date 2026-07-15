import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/functions_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../dto/story_dto.dart';
import '../mappers/story_mapper.dart';

class FirebaseStoryRepository implements StoryRepository {
  const FirebaseStoryRepository({
    required CollectionReference<StoryDto> stories,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _stories = stories,
       _firestore = firestore,
       _functions = functions;

  final CollectionReference<StoryDto> _stories;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Result<List<StoryGroup>>> loadStoryRail({
    required String viewerId,
    int limit = 40,
  }) async {
    try {
      final Set<String> hiddenUserIds = await _loadHiddenUserIds(viewerId);
      final int fetchLimit = ((limit * 2) + 1).clamp(1, 50).toInt();
      final QuerySnapshot<StoryDto> snapshot = await _stories
          .where('visibility', isEqualTo: 'public')
          .where('moderationState', isEqualTo: 'active')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(fetchLimit)
          .get();
      final List<QueryDocumentSnapshot<StoryDto>> visibleStories = snapshot.docs
          .where(
            (QueryDocumentSnapshot<StoryDto> item) =>
                !hiddenUserIds.contains(item.data().author.id),
          )
          .take(limit)
          .toList(growable: false);
      final List<DocumentSnapshot<Map<String, dynamic>>> viewSnapshots =
          await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
            visibleStories.map(
              (QueryDocumentSnapshot<StoryDto> item) => _firestore
                  .collection('story_views')
                  .doc('$viewerId--${item.id}')
                  .get(),
            ),
          );
      final Set<String> viewed = viewSnapshots
          .where((DocumentSnapshot<Map<String, dynamic>> item) => item.exists)
          .map(
            (DocumentSnapshot<Map<String, dynamic>> item) =>
                item.data()?['storyId'],
          )
          .whereType<String>()
          .toSet();
      final Map<String, List<Story>> byAuthor = <String, List<Story>>{};
      for (final QueryDocumentSnapshot<StoryDto> document in visibleStories) {
        final Story story = document.data().toDomain(
          isViewed: viewed.contains(document.id),
        );
        byAuthor.putIfAbsent(story.author.id, () => <Story>[]).add(story);
      }
      final List<StoryGroup> groups =
          byAuthor.values
              .where((List<Story> stories) => stories.isNotEmpty)
              .map(
                (List<Story> stories) =>
                    StoryGroup(author: stories.first.author, stories: stories),
              )
              .toList(growable: false)
            ..sort((StoryGroup a, StoryGroup b) {
              if (a.hasUnseen != b.hasUnseen) {
                return a.hasUnseen ? -1 : 1;
              }
              return b.stories.first.createdAt.compareTo(
                a.stories.first.createdAt,
              );
            });
      return Success<List<StoryGroup>>(groups);
    } on FirebaseException catch (error) {
      return FailureResult<List<StoryGroup>>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<List<StoryGroup>>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      return FailureResult<List<StoryGroup>>(_unexpected(error));
    }
  }

  Future<Set<String>> _loadHiddenUserIds(String viewerId) async {
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
        final QuerySnapshot<Map<String, dynamic>> page = await query.get();
        userIds.addAll(page.docs.map((item) => item.id));
        if (page.docs.length < 100) {
          break;
        }
        cursor = page.docs.last;
      }
    }
    return userIds;
  }

  @override
  Future<Result<void>> markViewed(String storyId) =>
      _callVoid('markStoryViewed', <String, Object?>{'storyId': storyId});

  @override
  Future<Result<void>> deleteStory(String storyId) =>
      _callVoid('deleteStory', <String, Object?>{'storyId': storyId});

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

  static Failure _unexpected(Object error) => Failure(
    message: 'ReeMove could not update stories. Try again.',
    code: 'stories/operation-failed',
    debugMessage: error.toString(),
    cause: error,
  );
}
