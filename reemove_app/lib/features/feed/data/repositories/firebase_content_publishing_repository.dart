import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/database/dto/media_asset_dto.dart';
import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/media_asset.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/functions_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/content_draft.dart';
import '../../domain/entities/feed_post.dart';
import '../../domain/entities/story.dart';
import '../../domain/entities/upload_status.dart';
import '../../domain/repositories/content_publishing_repository.dart';
import '../dto/feed_post_dto.dart';
import '../dto/story_dto.dart';
import '../mappers/feed_post_mapper.dart';
import '../mappers/story_mapper.dart';

class FirebaseContentPublishingRepository
    implements ContentPublishingRepository {
  const FirebaseContentPublishingRepository({
    required FirebaseStorage storage,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required CollectionReference<FeedPostDto> posts,
    required CollectionReference<StoryDto> stories,
  }) : _storage = storage,
       _firestore = firestore,
       _functions = functions,
       _posts = posts,
       _stories = stories;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final CollectionReference<FeedPostDto> _posts;
  final CollectionReference<StoryDto> _stories;

  @override
  Stream<MediaUploadStatus> uploadMedia({
    required String ownerId,
    required String draftId,
    required DraftMediaSelection selection,
  }) async* {
    final String assetId = _firestore.collection('media_assets').doc().id;
    final String storagePath =
        'content/$ownerId/$draftId/$assetId/${_safeFilename(selection.name)}';
    final Reference reference = _storage.ref(storagePath);
    final SettableMetadata metadata = SettableMetadata(
      contentType: selection.contentType,
      customMetadata: <String, String>{
        'ownerId': ownerId,
        'draftId': draftId,
        'assetId': assetId,
        'kind': selection.kind.name,
        'schemaVersion': '1',
      },
    );
    try {
      final UploadTask task = reference.putFile(
        File(selection.localPath),
        metadata,
      );
      await for (final TaskSnapshot snapshot in task.snapshotEvents) {
        final double progress = snapshot.totalBytes <= 0
            ? 0
            : snapshot.bytesTransferred / snapshot.totalBytes;
        yield MediaUploadStatus(
          assetId: assetId,
          progress: progress.clamp(0, 1).toDouble(),
          state: MediaProcessingState.pending,
        );
      }
      final String downloadUrl = await reference.getDownloadURL();
      final MediaAsset asset = MediaAsset(
        id: assetId,
        storagePath: storagePath,
        kind: selection.kind == DraftMediaKind.video
            ? MediaKind.video
            : MediaKind.image,
        processingState: selection.kind == DraftMediaKind.video
            ? MediaProcessingState.pending
            : MediaProcessingState.ready,
        downloadUrl: downloadUrl,
        contentType: selection.contentType,
        sizeBytes: selection.sizeBytes,
      );
      yield MediaUploadStatus(
        assetId: assetId,
        progress: 1,
        state: asset.processingState,
        asset: asset,
      );
    } on FirebaseException catch (error) {
      yield MediaUploadStatus(
        assetId: assetId,
        progress: 0,
        state: MediaProcessingState.failed,
        message: _storageFailure(error).message,
      );
    } catch (error) {
      yield MediaUploadStatus(
        assetId: assetId,
        progress: 0,
        state: MediaProcessingState.failed,
        message: 'ReeMove could not upload this media.',
      );
    }
  }

  @override
  Future<Result<void>> deleteUploadedMedia(MediaAsset asset) async {
    try {
      await _storage.ref(asset.storagePath).delete();
      return const Success<void>(null);
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return const Success<void>(null);
      }
      return FailureResult<void>(_storageFailure(error));
    } catch (error) {
      return FailureResult<void>(_unexpected(error));
    }
  }

  @override
  Future<Result<FeedPost>> publishPost({
    required ContentDraft draft,
    required List<MediaAsset> media,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('publishPost')
          .call<dynamic>(_publishRequest(draft, media));
      final Map<String, dynamic> data = _map(response.data);
      final String postId = data['postId'] as String;
      final DocumentSnapshot<FeedPostDto> snapshot = await _posts
          .doc(postId)
          .get();
      final FeedPostDto? post = snapshot.data();
      if (post == null) {
        throw StateError('The published post is unavailable.');
      }
      return Success<FeedPost>(post.toDomain());
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<FeedPost>(
        FunctionsFailureMapper.fromException(error),
      );
    } on FirebaseException catch (error) {
      return FailureResult<FeedPost>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } catch (error) {
      return FailureResult<FeedPost>(_unexpected(error));
    }
  }

  @override
  Future<Result<Story>> publishStory({
    required ContentDraft draft,
    required MediaAsset media,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('publishStory')
          .call<dynamic>(_publishRequest(draft, <MediaAsset>[media]));
      final Map<String, dynamic> data = _map(response.data);
      final String storyId = data['storyId'] as String;
      final DocumentSnapshot<StoryDto> snapshot = await _stories
          .doc(storyId)
          .get();
      final StoryDto? story = snapshot.data();
      if (story == null) {
        throw StateError('The published story is unavailable.');
      }
      return Success<Story>(story.toDomain(isViewed: false));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<Story>(FunctionsFailureMapper.fromException(error));
    } on FirebaseException catch (error) {
      return FailureResult<Story>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } catch (error) {
      return FailureResult<Story>(_unexpected(error));
    }
  }

  static Map<String, Object?> _publishRequest(
    ContentDraft draft,
    List<MediaAsset> media,
  ) {
    return <String, Object?>{
      'draftId': draft.id,
      'kind': draft.kind.name,
      'caption': draft.caption,
      'media': media
          .map((MediaAsset item) => MediaAssetDto.fromDomain(item).toMap())
          .toList(growable: false),
      if (draft.sportId != null) 'sportId': draft.sportId,
      if (draft.locationLabel != null) 'locationLabel': draft.locationLabel,
      'visibility': draft.visibility.storageValue,
      'allowComments': draft.allowComments,
    };
  }

  static String _safeFilename(String value) {
    final String normalized = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return normalized.isEmpty ? 'upload' : normalized;
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

  static Failure _storageFailure(FirebaseException error) => Failure(
    message: switch (error.code) {
      'unauthenticated' => 'Sign in again before uploading.',
      'unauthorized' => 'This upload is not permitted.',
      'canceled' => 'The upload was canceled.',
      'retry-limit-exceeded' => 'The upload took too long. Try again.',
      _ => 'ReeMove could not upload this media.',
    },
    code: 'storage/${error.code}',
    debugMessage: error.message,
    cause: error,
  );

  static Failure _unexpected(Object error) => Failure(
    message: 'ReeMove could not publish this content. Try again.',
    code: 'content/publish-failed',
    debugMessage: error.toString(),
    cause: error,
  );
}
