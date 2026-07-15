import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/content_draft.dart';
import '../../domain/repositories/content_draft_repository.dart';

class SharedPreferencesContentDraftRepository
    implements ContentDraftRepository {
  const SharedPreferencesContentDraftRepository();

  static String _key(DraftKind kind) => 'reemove.content_draft.${kind.name}.v1';

  @override
  Future<Result<ContentDraft?>> load(DraftKind kind) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? encoded = preferences.getString(_key(kind));
      if (encoded == null) {
        return const Success<ContentDraft?>(null);
      }
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        throw const FormatException('Invalid draft data.');
      }
      final Map<String, dynamic> data = decoded.cast<String, dynamic>();
      return Success<ContentDraft?>(_fromMap(data));
    } catch (error) {
      return FailureResult<ContentDraft?>(_failure(error));
    }
  }

  @override
  Future<Result<void>> save(ContentDraft draft) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setString(_key(draft.kind), jsonEncode(_toMap(draft)));
      return const Success<void>(null);
    } catch (error) {
      return FailureResult<void>(_failure(error));
    }
  }

  @override
  Future<Result<void>> clear(DraftKind kind) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.remove(_key(kind));
      return const Success<void>(null);
    } catch (error) {
      return FailureResult<void>(_failure(error));
    }
  }

  static ContentDraft _fromMap(Map<String, dynamic> data) {
    final List<Object?> rawMedia = data['media'] is List
        ? (data['media'] as List).cast<Object?>()
        : const <Object?>[];
    return ContentDraft(
      id: data['id'] as String,
      kind: DraftKind.values.byName(data['kind'] as String),
      caption: data['caption'] as String? ?? '',
      media: rawMedia
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> media) {
            return DraftMediaSelection(
              localPath: media['localPath'] as String,
              name: media['name'] as String,
              kind: DraftMediaKind.values.byName(media['kind'] as String),
              contentType: media['contentType'] as String,
              sizeBytes: (media['sizeBytes'] as num).toInt(),
            );
          })
          .toList(growable: false),
      sportId: data['sportId'] as String?,
      locationLabel: data['locationLabel'] as String?,
      visibility: Visibility.values.byName(
        data['visibility'] as String? ?? Visibility.public.name,
      ),
      allowComments: data['allowComments'] as bool? ?? true,
      createdAt: DateTime.parse(data['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(data['updatedAt'] as String).toUtc(),
    );
  }

  static Map<String, Object?> _toMap(ContentDraft draft) => <String, Object?>{
    'id': draft.id,
    'kind': draft.kind.name,
    'caption': draft.caption,
    'media': draft.media
        .map(
          (DraftMediaSelection media) => <String, Object?>{
            'localPath': media.localPath,
            'name': media.name,
            'kind': media.kind.name,
            'contentType': media.contentType,
            'sizeBytes': media.sizeBytes,
          },
        )
        .toList(growable: false),
    if (draft.sportId != null) 'sportId': draft.sportId,
    if (draft.locationLabel != null) 'locationLabel': draft.locationLabel,
    'visibility': draft.visibility.name,
    'allowComments': draft.allowComments,
    'createdAt': draft.createdAt.toIso8601String(),
    'updatedAt': draft.updatedAt.toIso8601String(),
  };

  static Failure _failure(Object error) => Failure(
    message: 'ReeMove could not restore this draft.',
    code: 'content/draft-storage',
    debugMessage: error.toString(),
    cause: error,
  );
}
