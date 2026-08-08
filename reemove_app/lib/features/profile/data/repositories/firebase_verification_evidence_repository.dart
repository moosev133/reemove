import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/debug/staging_diagnostics.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/profile_image.dart';
import '../../domain/entities/verification_request.dart';
import '../../domain/repositories/verification_evidence_repository.dart';
import '../../domain/services/verification_evidence_validator.dart';

class FirebaseVerificationEvidenceRepository
    implements VerificationEvidenceRepository {
  const FirebaseVerificationEvidenceRepository(this._storage);

  final FirebaseStorage _storage;

  static const int maxBytes = 15 * 1024 * 1024;

  @override
  Future<Result<VerificationEvidence>> upload({
    required String uid,
    required String label,
    required ProfileImageSource source,
    VerificationDocumentKind documentKind = VerificationDocumentKind.other,
    String? issuer,
    DateTime? issuedAt,
    DateTime? expiresAt,
    void Function(double progress)? onProgress,
    void Function(VerificationUploadProgress progress)? onDetailedProgress,
    void Function(Future<bool> Function() cancel)? onRegisterCancel,
  }) async {
    Reference? target;
    StreamSubscription<TaskSnapshot>? progressSubscription;
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final Failure? validation = VerificationEvidenceValidator.validateSource(
        source,
      );
      if (validation != null) {
        return FailureResult<VerificationEvidence>(validation);
      }
      final String contentType =
          VerificationEvidenceValidator.resolveContentType(
            bytes: source.bytes,
            declaredContentType: source.contentType,
            filename: source.filename,
          );
      final String id = DateTime.now().microsecondsSinceEpoch.toString();
      target = _storage.ref(
        'verification/$uid/$uid/$id.${_extension(contentType)}',
      );
      final UploadTask task = target.putData(
        source.bytes,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'private,max-age=3600',
          customMetadata: <String, String>{
            'ownerId': uid,
            'schemaVersion': '1',
            'purpose': 'profile-verification',
            'documentKind': documentKind.name,
          },
        ),
      );
      onRegisterCancel?.call(() => task.cancel());
      StagingDiagnostics.log('VERIFICATION_UPLOAD_TASK_CREATED', <String, Object?>{
        'path': target.fullPath,
        'sizeBytes': source.bytes.lengthInBytes,
        'contentType': contentType,
      });
      if (onProgress != null) {
        progressSubscription = task.snapshotEvents.listen((TaskSnapshot snap) {
          final int total = snap.totalBytes;
          onProgress(total <= 0 ? 0 : snap.bytesTransferred / total);
          onDetailedProgress?.call(
            VerificationUploadProgress(
              bytesTransferred: snap.bytesTransferred,
              totalBytes: total,
            ),
          );
          StagingDiagnostics.log('VERIFICATION_UPLOAD_PROGRESS', <String, Object?>{
            'bytesTransferred': snap.bytesTransferred,
            'totalBytes': total,
            'state': snap.state.name,
          });
        });
      }
      await task;
      onProgress?.call(1);
      onDetailedProgress?.call(
        VerificationUploadProgress(
          bytesTransferred: source.bytes.lengthInBytes,
          totalBytes: source.bytes.lengthInBytes,
        ),
      );
      StagingDiagnostics.log('VERIFICATION_UPLOAD_COMPLETED', <String, Object?>{
        'path': target.fullPath,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
      return Success<VerificationEvidence>(
        VerificationEvidence(
          storagePath: target.fullPath,
          label: label,
          documentKind: documentKind,
          contentType: contentType,
          sizeBytes: source.bytes.lengthInBytes,
          issuer: issuer,
          issuedAt: issuedAt,
          expiresAt: expiresAt,
        ),
      );
    } on FirebaseException catch (error) {
      if (target != null) {
        try {
          await target.delete();
        } on FirebaseException {
          // Best-effort rollback.
        }
      }
      return FailureResult<VerificationEvidence>(
        Failure(
          message: _uploadErrorMessage(error),
          code: 'storage/${error.code}',
          debugMessage: error.message,
          cause: error,
        ),
      );
    } catch (error) {
      return FailureResult<VerificationEvidence>(
        Failure(
          message:
              'The verification evidence could not be uploaded. Check your '
              'network connection and try again.',
          code: 'profile/verification-upload',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    } finally {
      await progressSubscription?.cancel();
    }
  }

  static String _uploadErrorMessage(FirebaseException error) {
    final String code = error.code.toLowerCase();
    if (code.contains('unauthorized') ||
        code.contains('permission-denied') ||
        code == 'storage/unauthorized') {
      return 'Upload blocked by Storage security rules. Sign in again and '
          'retry with a PNG or JPEG under 15 MB.';
    }
    if (code.contains('canceled')) {
      return 'Upload was canceled. Tap Retry to continue.';
    }
    if (code.contains('retry-limit') ||
        code.contains('network') ||
        code.contains('unavailable')) {
      return 'Network error while uploading evidence. Check connectivity and tap Retry.';
    }
    if (code.contains('quota') || code.contains('resource-exhausted')) {
      return 'Upload quota exceeded. Try again later or choose a smaller image.';
    }
    final String detail = (error.message ?? '').trim();
    return 'The verification evidence could not be uploaded '
        '(${error.code}${detail.isEmpty ? '' : ': $detail'}). Tap Retry or Replace.';
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
