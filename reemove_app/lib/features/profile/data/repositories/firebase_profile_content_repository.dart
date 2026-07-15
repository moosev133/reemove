import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/result/result.dart';
import '../../../feed/data/dto/content_reaction_dto.dart';
import '../../../feed/data/dto/feed_post_dto.dart';
import '../../../feed/data/mappers/feed_post_mapper.dart';
import '../../../feed/domain/entities/feed_post.dart';
import '../../domain/entities/profile_content_page.dart';
import '../../domain/repositories/profile_content_repository.dart';
import '../services/profile_failure_mapper.dart';

class FirebaseProfileContentRepository implements ProfileContentRepository {
  const FirebaseProfileContentRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Result<ProfileContentPage>> load({
    required String profileId,
    required String viewerId,
    required ProfileContentFilter filter,
    int limit = 18,
    ProfileContentCursor? cursor,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('loadProfileContent')
          .call<dynamic>(<String, Object?>{
            'profileId': profileId,
            'filter': filter.name,
            'limit': limit,
            if (cursor != null) ...<String, Object?>{
              'cursorId': cursor.documentId,
              'cursorAt': cursor.sortAt.toUtc().toIso8601String(),
            },
          });
      final Map<String, dynamic> data = _map(response.data);
      final List<FeedPost>
      items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> raw) {
            final Map<String, dynamic> item = Map<String, dynamic>.from(raw);
            final Map<String, dynamic> postMap = Map<String, dynamic>.from(
              item['post'] as Map,
            );
            final Map<String, dynamic>? reactionMap = item['reaction'] is Map
                ? Map<String, dynamic>.from(item['reaction'] as Map)
                : null;
            final FeedPostDto post = FeedPostDto.fromMap(
              postMap,
              documentId: postMap['id'] as String,
            );
            final ContentReactionDto? reaction = reactionMap == null
                ? null
                : ContentReactionDto.fromMap(reactionMap);
            return post.toDomain(reaction: reaction);
          })
          .toList(growable: false);
      final Map<String, dynamic>? cursorMap = data['nextCursor'] is Map
          ? (data['nextCursor'] as Map).cast<String, dynamic>()
          : null;
      return Success<ProfileContentPage>(
        ProfileContentPage(
          items: items,
          hasMore: data['hasMore'] == true,
          nextCursor: cursorMap == null
              ? null
              : ProfileContentCursor(
                  documentId: cursorMap['documentId'] as String,
                  sortAt: DateTime.parse(cursorMap['sortAt'] as String).toUtc(),
                ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<ProfileContentPage>(
        ProfileFailureMapper.fromFunctions(error),
      );
    } catch (error) {
      return FailureResult<ProfileContentPage>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const FormatException('The profile service returned invalid data.');
  }
}
