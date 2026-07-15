import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/profile_image.dart';
import '../../domain/entities/verification_request.dart';
import '../../domain/repositories/verification_evidence_repository.dart';

class FirebaseVerificationEvidenceRepository
    implements VerificationEvidenceRepository {
  const FirebaseVerificationEvidenceRepository(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<Result<VerificationEvidence>> upload({
    required String uid,
    required String label,
    required ProfileImageSource source,
  }) async {
    Reference? target;
    try {
      final String id = DateTime.now().microsecondsSinceEpoch.toString();
      target = _storage.ref(
        'verification/$uid/$uid/$id.${_extension(source.contentType)}',
      );
      await target.putData(
        source.bytes,
        SettableMetadata(
          contentType: source.contentType,
          cacheControl: 'private,max-age=3600',
          customMetadata: <String, String>{
            'ownerId': uid,
            'schemaVersion': '1',
            'purpose': 'profile-verification',
          },
        ),
      );
      return Success<VerificationEvidence>(
        VerificationEvidence(storagePath: target.fullPath, label: label),
      );
    } on FirebaseException catch (error) {
      if (target != null) {
        try {
          await target.delete();
        } on FirebaseException {
          // Best-effort rollback. Storage lifecycle cleanup handles leftovers.
        }
      }
      return FailureResult<VerificationEvidence>(
        Failure(
          message: 'The verification evidence could not be uploaded.',
          code: 'storage/${error.code}',
          debugMessage: error.message,
          cause: error,
        ),
      );
    } catch (error) {
      return FailureResult<VerificationEvidence>(
        Failure(
          message: 'The verification evidence could not be uploaded.',
          code: 'profile/verification-upload',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete({
    required String uid,
    required String storagePath,
  }) async {
    final String prefix = 'verification/$uid/';
    if (!storagePath.startsWith(prefix)) {
      return const FailureResult<void>(
        Failure(
          message: 'This verification file cannot be removed.',
          code: 'profile/verification-path',
        ),
      );
    }
    try {
      await _storage.ref(storagePath).delete();
      return const Success<void>(null);
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return const Success<void>(null);
      }
      return FailureResult<void>(
        Failure(
          message: 'The verification file could not be removed.',
          code: 'storage/${error.code}',
          debugMessage: error.message,
          cause: error,
        ),
      );
    } catch (error) {
      return FailureResult<void>(
        Failure(
          message: 'The verification file could not be removed.',
          code: 'profile/verification-delete',
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
