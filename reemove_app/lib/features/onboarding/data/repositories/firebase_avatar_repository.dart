import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/avatar_asset.dart';
import '../../domain/repositories/avatar_repository.dart';

class FirebaseAvatarRepository implements AvatarRepository {
  const FirebaseAvatarRepository(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<Result<AvatarAsset>> upload({
    required String uid,
    required AvatarUploadSource source,
    String? previousStoragePath,
  }) async {
    Reference? uploadedReference;
    try {
      if (source.bytes.isEmpty || source.bytes.length >= 10 * 1024 * 1024) {
        return const FailureResult<AvatarAsset>(
          Failure(
            message: 'Choose an image smaller than 10 MB.',
            code: 'avatar/invalid-size',
          ),
        );
      }

      final String extension = _extensionFor(source.contentType);
      final String assetId = DateTime.now().microsecondsSinceEpoch.toString();
      uploadedReference = _storage.ref('users/$uid/avatar/$assetId.$extension');
      await uploadedReference.putData(
        source.bytes,
        SettableMetadata(
          contentType: source.contentType,
          cacheControl: 'public,max-age=86400',
          customMetadata: <String, String>{
            'ownerId': uid,
            'schemaVersion': '1',
            'originalFilename': _safeFilename(source.filename),
          },
        ),
      );
      final String downloadUrl = await uploadedReference.getDownloadURL();

      if (previousStoragePath != null &&
          previousStoragePath.startsWith('users/$uid/avatar/') &&
          previousStoragePath != uploadedReference.fullPath) {
        try {
          await _storage.ref(previousStoragePath).delete();
        } on FirebaseException {
          // A stale avatar is harmless and can be removed by lifecycle cleanup.
        }
      }

      return Success<AvatarAsset>(
        AvatarAsset(
          downloadUrl: downloadUrl,
          storagePath: uploadedReference.fullPath,
        ),
      );
    } on FirebaseException catch (error) {
      if (uploadedReference != null) {
        try {
          await uploadedReference.delete();
        } on FirebaseException {
          // Best-effort rollback only.
        }
      }
      return FailureResult<AvatarAsset>(
        Failure(
          message: _messageFor(error.code),
          code: 'storage/${error.code}',
          debugMessage: error.message,
          cause: error,
        ),
      );
    } catch (error) {
      return FailureResult<AvatarAsset>(
        Failure(
          message: 'The avatar could not be uploaded. Try again.',
          code: 'avatar/unexpected',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }

  static String _extensionFor(String contentType) => switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/heic' || 'image/heif' => 'heic',
    _ => 'jpg',
  };

  static String _safeFilename(String value) {
    final String cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.length <= 100 ? cleaned : cleaned.substring(0, 100);
  }

  static String _messageFor(String code) => switch (code) {
    'unauthorized' => 'You do not have permission to upload this avatar.',
    'canceled' => 'Avatar upload was canceled.',
    'retry-limit-exceeded' =>
      'The upload connection was interrupted. Try again.',
    _ => 'The avatar could not be uploaded. Try again.',
  };
}
