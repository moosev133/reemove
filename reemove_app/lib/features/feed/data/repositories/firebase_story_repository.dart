import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/database/dto/media_asset_dto.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/functions_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../dto/feed_post_dto.dart';
import '../dto/story_dto.dart';
import '../mappers/story_mapper.dart';

class FirebaseStoryRepository implements StoryRepository {
  const FirebaseStoryRepository({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<Result<List<StoryGroup>>> loadStoryRail({
    required String viewerId,
    int limit = 40,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('loadStoryRail')
          .call<dynamic>(<String, Object?>{'limit': limit});
      final Map<String, dynamic> data = _map(response.data);
      final List<StoryGroup> groups =
          (data['groups'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<Object?, Object?>>()
              .map(
                (Map<Object?, Object?> item) =>
                    _parseGroup(Map<String, dynamic>.from(item)),
              )
              .whereType<StoryGroup>()
              .toList(growable: false);
      return Success<List<StoryGroup>>(groups);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<StoryGroup>>(
        FunctionsFailureMapper.fromException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<List<StoryGroup>>(
        Failure(
          message: 'ReeMove could not load stories. Try again.',
          code: 'stories/load-failed',
          debugMessage: error.message,
          cause: error,
        ),
      );
    } catch (error) {
      return FailureResult<List<StoryGroup>>(_unexpected(error));
    }
  }

  @override
  Future<Result<void>> markViewed(String storyId) =>
      _callVoid('markStoryViewed', <String, Object?>{'storyId': storyId});

  @override
  Future<Result<void>> deleteStory(String storyId) =>
      _callVoid('deleteStory', <String, Object?>{'storyId': storyId});

  StoryGroup? _parseGroup(Map<String, dynamic> data) {
    final List<Story> stories =
        (data['stories'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> item) =>
                  _parseStory(Map<String, dynamic>.from(item)),
            )
            .whereType<Story>()
            .toList(growable: false);
    if (stories.isEmpty) {
      return null;
    }
    return StoryGroup(author: stories.first.author, stories: stories);
  }

  Story? _parseStory(Map<String, dynamic> data) {
    try {
      final String id = data['id'] is String ? data['id'] as String : '';
      if (id.isEmpty) {
        return null;
      }
      final Map<String, dynamic>? authorMap = data['authorSnapshot'] is Map
          ? (data['authorSnapshot'] as Map).cast<String, dynamic>()
          : data['author'] is Map
          ? (data['author'] as Map).cast<String, dynamic>()
          : null;
      final Map<String, dynamic>? mediaMap = data['media'] is Map
          ? (data['media'] as Map).cast<String, dynamic>()
          : null;
      if (authorMap == null || mediaMap == null) {
        return null;
      }
      final StoryDto dto = StoryDto(
        id: id,
        author: PostAuthorSnapshotDto.fromMap(authorMap),
        media: _storyMediaFromMap(mediaMap, id),
        caption: data['caption'] is String ? data['caption'] as String : null,
        sportId: data['sportId'] is String ? data['sportId'] as String : null,
        visibility: data['visibility'] is String
            ? data['visibility'] as String
            : 'public',
        moderationState: data['moderationState'] is String
            ? data['moderationState'] as String
            : 'active',
        createdAt: DateTime.parse(data['createdAt'] as String).toUtc(),
        expiresAt: DateTime.parse(data['expiresAt'] as String).toUtc(),
        viewCount: data['viewCount'] is num
            ? (data['viewCount'] as num).toInt()
            : 0,
      );
      return dto.toDomain(isViewed: data['isViewed'] == true);
    } catch (_) {
      // Skip malformed stories so one bad payload cannot blank the rail.
      return null;
    }
  }

  /// Accepts canonical MediaAsset maps and compact story payloads (`type`/`url`).
  static MediaAssetDto _storyMediaFromMap(
    Map<String, dynamic> mediaMap,
    String storyId,
  ) {
    final String? kindRaw = mediaMap['kind'] is String
        ? mediaMap['kind'] as String
        : mediaMap['type'] is String
        ? mediaMap['type'] as String
        : null;
    final String kind = kindRaw == 'video' ? 'video' : 'image';
    final String? downloadUrl = mediaMap['downloadUrl'] is String
        ? mediaMap['downloadUrl'] as String
        : mediaMap['url'] is String
        ? mediaMap['url'] as String
        : null;
    final String id = mediaMap['id'] is String &&
            (mediaMap['id'] as String).isNotEmpty
        ? mediaMap['id'] as String
        : 'story-media-$storyId';
    final String storagePath = mediaMap['storagePath'] is String &&
            (mediaMap['storagePath'] as String).isNotEmpty
        ? mediaMap['storagePath'] as String
        : 'stories/$storyId/media';
    final String processingState = mediaMap['processingState'] is String &&
            (mediaMap['processingState'] as String).isNotEmpty
        ? mediaMap['processingState'] as String
        : 'ready';
    return MediaAssetDto(
      id: id,
      storagePath: storagePath,
      kind: kind,
      processingState: processingState,
      downloadUrl: downloadUrl,
      thumbnailUrl: mediaMap['thumbnailUrl'] is String
          ? mediaMap['thumbnailUrl'] as String
          : null,
      width: mediaMap['width'] is num ? (mediaMap['width'] as num).toInt() : null,
      height: mediaMap['height'] is num
          ? (mediaMap['height'] as num).toInt()
          : null,
      durationMs: mediaMap['durationMs'] is num
          ? (mediaMap['durationMs'] as num).toInt()
          : null,
      blurHash: mediaMap['blurHash'] is String
          ? mediaMap['blurHash'] as String
          : null,
      contentType: mediaMap['contentType'] is String
          ? mediaMap['contentType'] as String
          : null,
      sizeBytes: mediaMap['sizeBytes'] is num
          ? (mediaMap['sizeBytes'] as num).toInt()
          : null,
    );
  }

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

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const FormatException('The story service returned invalid data.');
  }

  static Failure _unexpected(Object error) => Failure(
    message: 'ReeMove could not update stories. Try again.',
    code: 'stories/operation-failed',
    debugMessage: error.toString(),
    cause: error,
  );
}
