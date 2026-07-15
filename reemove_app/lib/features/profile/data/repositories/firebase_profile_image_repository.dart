import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/profile_image.dart';
import '../../domain/repositories/profile_image_repository.dart';

class FirebaseProfileImageRepository implements ProfileImageRepository {
  const FirebaseProfileImageRepository(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<Result<ProfileImageAsset>> upload({
    required String uid,
    required ProfileImageKind kind,
    required ProfileImageSource source,
    String? previousStoragePath,
  }) async {
    Reference? uploaded;
    try {
      final String folder = kind.name;
      final String extension = _extension(source.contentType);
      final String id = DateTime.now().microsecondsSinceEpoch.toString();
      uploaded = _storage.ref('users/$uid/$folder/$id.$extension');
      await uploaded.putData(
        source.bytes,
        SettableMetadata(
          contentType: source.contentType,
          cacheControl: 'public,max-age=86400',
          customMetadata: <String, String>{
            'ownerId': uid,
            'schemaVersion': '1',
            'kind': folder,
          },
        ),
      );
      final String url = await uploaded.getDownloadURL();
      if (previousStoragePath != null &&
          previousStoragePath.startsWith('users/$uid/$folder/') &&
          previousStoragePath != uploaded.fullPath) {
        try {
          await _storage.ref(previousStoragePath).delete();
        } on FirebaseException {
          // Lifecycle cleanup removes stale images if deletion is interrupted.
        }
      }
      return Success<ProfileImageAsset>(
        ProfileImageAsset(downloadUrl: url, storagePath: uploaded.fullPath),
      );
    } on FirebaseException catch (error) {
      if (uploaded != null) {
        try {
          await uploaded.delete();
        } on FirebaseException {
          // Best-effort rollback.
        }
      }
      return FailureResult<ProfileImageAsset>(
        Failure(
          message: 'The profile image could not be uploaded.',
          code: 'storage/${error.code}',
          debugMessage: error.message,
          cause: error,
        ),
      );
    } catch (error) {
      return FailureResult<ProfileImageAsset>(
        Failure(
          message: 'The profile image could not be uploaded.',
          code: 'profile/image-upload',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }

  static String _extension(String contentType) => switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/heic' || 'image/heif' => 'heic',
    _ => 'jpg',
  };
}
